import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/balance_engine.dart';
import '../domain/split_engine.dart';
import 'even_database.dart';

class EvenRepository {
  EvenRepository(this._database);
  final EvenDatabase _database;
  static const _uuid = Uuid();

  Future<List<EvenGroup>> groups() async {
    final db = await _database.database;
    final rows = await db.query('groups', where: 'archived = 0', orderBy: 'created_at DESC');
    return rows.map(EvenGroup.fromMap).toList();
  }

  Future<List<EvenExpense>> expenses() async {
    final db = await _database.database;
    final rows = await db.query('expenses', where: 'deleted_at IS NULL', orderBy: 'created_at DESC', limit: 50);
    return rows.map(EvenExpense.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> expenseShares(String expenseId) async {
    final db = await _database.database;
    return db.query('expense_shares', columns: ['person_id', 'amount_minor'],
      where: 'expense_id = ?', whereArgs: [expenseId], orderBy: 'person_id COLLATE NOCASE');
  }

  Future<void> addGroup(String name, List<String> members) async {
    final clean = members.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (!clean.contains('You')) clean.insert(0, 'You');
    final db = await _database.database;
    await db.insert('groups', {'id': _uuid.v4(), 'name': name.trim(), 'members': clean.join('|'), 'created_at': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> updateGroupMembers(String groupId, List<String> members) async {
    final clean = members.map((person) => person.trim()).where((person) => person.isNotEmpty).toSet().toList();
    if (!clean.contains('You')) clean.insert(0, 'You');
    final db = await _database.database;
    final changed = await db.update('groups', {'members': clean.join('|')}, where: 'id = ? AND archived = 0', whereArgs: [groupId]);
    if (changed == 0) throw StateError('Group not found.');
  }

  Future<void> addExpense({
    required String title,
    required int amountMinor,
    required String paidBy,
    required List<String> participants,
    String? groupId,
    String currency = 'INR',
    SplitMethod splitMethod = SplitMethod.equal,
    List<SplitInput>? splitInputs,
  }) async {
    final cleanTitle = title.trim();
    final cleanPayer = paidBy.trim();
    final cleanParticipants = participants.map((person) => person.trim()).toList();
    if (cleanTitle.isEmpty || amountMinor <= 0 || cleanPayer.isEmpty || cleanParticipants.isEmpty) {
      throw ArgumentError('Enter a title, positive amount, payer and at least one participant.');
    }
    if (cleanParticipants.any((person) => person.isEmpty) ||
        cleanParticipants.toSet().length != cleanParticipants.length) {
      throw ArgumentError('Participants must be non-empty and unique.');
    }
    final id = _uuid.v4();
    final inputs = splitInputs ??
        cleanParticipants.map((person) => SplitInput(personId: person)).toList();
    if (inputs.length != cleanParticipants.length ||
        inputs.map((input) => input.personId).toSet().length != cleanParticipants.length ||
        !inputs.every((input) => cleanParticipants.contains(input.personId))) {
      throw ArgumentError('Split inputs must match the selected participants exactly.');
    }
    final shares = SplitEngine.split(
      totalMinor: amountMinor,
      participants: inputs,
      method: splitMethod,
    );
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('expenses', {'id': id, 'title': cleanTitle, 'amount_minor': amountMinor, 'currency': currency, 'paid_by': cleanPayer, 'group_id': groupId, 'split_method': splitMethod.name, 'created_at': DateTime.now().millisecondsSinceEpoch});
      final batch = txn.batch();
      shares.forEach((person, amount) => batch.insert('expense_shares', {'expense_id': id, 'person_id': person, 'amount_minor': amount}));
      await batch.commit(noResult: true);
      await txn.insert('activity', {'id': _uuid.v4(), 'event_type': 'expense_added', 'description': 'Added $title', 'created_at': DateTime.now().millisecondsSinceEpoch});
    });
  }


  /// Positive values are owed to a person; negative values are owed by them.
  Future<Map<String, int>> netBalances() async {
    final db = await _database.database;
    final expenses = await db.query('expenses',
      columns: ['id', 'amount_minor', 'paid_by', 'deleted_at'],
      where: 'deleted_at IS NULL');
    final ids = expenses.map((row) => row['id'] as String).toList();
    final shares = <Map<String, Object?>>[];
    if (ids.isNotEmpty) {
      final marks = List.filled(ids.length, '?').join(',');
      shares.addAll(await db.rawQuery(
        'SELECT expense_id, person_id, amount_minor FROM expense_shares WHERE expense_id IN ($marks)', ids));
    }
    final settlements = await db.query('settlements',
      columns: ['from_person', 'to_person', 'amount_minor', 'deleted_at'],
      where: 'deleted_at IS NULL');
    return BalanceEngine.calculate(expenses: expenses, shares: shares, settlements: settlements);
  }

  Future<List<Transfer>> suggestedTransfers() async =>
      BalanceEngine.suggestedTransfers(await netBalances());

  Future<List<Map<String, Object?>>> settlementHistory({int limit = 100}) async {
    final db = await _database.database;
    return db.query('settlements', where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC', limit: limit);
  }

  Future<void> recordSettlement({
    required String fromPerson, required String toPerson,
    required int amountMinor, String? note,
  }) async {
    final from = fromPerson.trim();
    final to = toPerson.trim();
    if (from.isEmpty || to.isEmpty || from == to || amountMinor <= 0) {
      throw ArgumentError('Choose two different people and a positive amount.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('settlements', {
        'id': _uuid.v4(), 'from_person': from, 'to_person': to,
        'amount_minor': amountMinor, 'currency': 'INR', 'note': note?.trim(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await txn.insert('activity', {
        'id': _uuid.v4(), 'event_type': 'settlement_recorded',
        'description': '$from paid $to', 'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// Soft-delete a settlement so the audit trail is retained.
  Future<void> voidSettlement(String settlementId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final changed = await txn.update('settlements',
        {'deleted_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ? AND deleted_at IS NULL', whereArgs: [settlementId]);
      if (changed == 0) throw StateError('Settlement not found or already reversed.');
      await txn.insert('activity', {
        'id': _uuid.v4(), 'event_type': 'settlement_reversed',
        'description': 'A settlement was reversed',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<int> totalSpentMinor() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses WHERE deleted_at IS NULL');
    return (rows.first['total'] as int?) ?? 0;
  }
}

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

  Future<void> addGroup(String name, List<String> members) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Group name cannot be empty.');
    final clean = <String>[];
    final seen = <String>{};
    for (final raw in members) {
      final value = raw.trim();
      if (value.isNotEmpty && seen.add(value.toLowerCase())) clean.add(value);
    }
    if (seen.add('you')) clean.insert(0, 'You');
    final db = await _database.database;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('groups', {'id': id, 'name': cleanName, 'members': clean.join('|'), 'created_at': now});
      final batch = txn.batch();
      for (final person in clean) {
        batch.insert('group_members', {
          'group_id': id, 'person_id': person.toLowerCase(), 'display_name': person,
          'role': person == 'You' ? 'owner' : 'member', 'added_at': now,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<String>> groupMembers(String groupId) async {
    final db = await _database.database;
    final rows = await db.query('group_members', columns: ['display_name'],
      where: 'group_id = ?', whereArgs: [groupId],
      orderBy: "CASE WHEN role = 'owner' THEN 0 ELSE 1 END, added_at");
    return rows.map((row) => row['display_name'] as String).toList();
  }

  Future<List<EvenExpense>> groupExpenses(String groupId) async {
    final db = await _database.database;
    final rows = await db.query('expenses',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId], orderBy: 'created_at DESC', limit: 100);
    return rows.map(EvenExpense.fromMap).toList();
  }

  Future<void> addGroupMember(String groupId, String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('Enter a person's name.');
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query('group_members', columns: ['person_id'],
        where: 'group_id = ?', whereArgs: [groupId]);
      if (rows.any((row) => (row['person_id'] as String).toLowerCase() == name.toLowerCase())) {
        throw ArgumentError('That person is already in this group.');
      }
      await txn.insert('group_members', {
        'group_id': groupId, 'person_id': name.toLowerCase(), 'display_name': name,
        'role': 'member', 'added_at': DateTime.now().millisecondsSinceEpoch,
      });
      final group = (await txn.query('groups', columns: ['members'],
        where: 'id = ?', whereArgs: [groupId])).first;
      final names = (group['members'] as String? ?? '').split('|')
        .where((value) => value.isNotEmpty).toList()..add(name);
      await txn.update('groups', {'members': names.join('|')}, where: 'id = ?', whereArgs: [groupId]);
    });
  }

  Future<void> removeGroupMember(String groupId, String displayName) async {
    final name = displayName.trim();
    if (name.toLowerCase() == 'you') throw ArgumentError('The group owner cannot be removed.');
    final db = await _database.database;
    await db.transaction((txn) async {
      final refs = await txn.rawQuery('''
        SELECT COUNT(*) AS total FROM expense_shares s
        INNER JOIN expenses e ON e.id = s.expense_id
        WHERE e.group_id = ? AND e.deleted_at IS NULL AND lower(s.person_id) = lower(?)
      ''', [groupId, name]);
      if ((refs.first['total'] as int) > 0) {
        throw StateError('This person has expense history in the group and cannot be removed.');
      }
      await txn.delete('group_members', where: 'group_id = ? AND person_id = ?',
        whereArgs: [groupId, name.toLowerCase()]);
      final group = (await txn.query('groups', columns: ['members'],
        where: 'id = ?', whereArgs: [groupId])).first;
      final names = (group['members'] as String? ?? '').split('|')
        .where((value) => value.isNotEmpty && value.toLowerCase() != name.toLowerCase()).toList();
      await txn.update('groups', {'members': names.join('|')}, where: 'id = ?', whereArgs: [groupId]);
    });
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

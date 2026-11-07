import 'package:uuid/uuid.dart';
import '../domain/models.dart';
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
    final clean = members.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (!clean.contains('You')) clean.insert(0, 'You');
    final db = await _database.database;
    await db.insert('groups', {'id': _uuid.v4(), 'name': name.trim(), 'members': clean.join('|'), 'created_at': DateTime.now().millisecondsSinceEpoch});
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

  Future<int> totalSpentMinor() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses WHERE deleted_at IS NULL');
    return (rows.first['total'] as int?) ?? 0;
  }
}

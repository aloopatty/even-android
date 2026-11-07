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

  Future<void> addExpense({required String title, required int amountMinor, required String paidBy, required List<String> participants, String? groupId, String currency = 'INR'}) async {
    if (title.trim().isEmpty || amountMinor <= 0 || participants.isEmpty) throw ArgumentError('Enter a title, positive amount and at least one participant.');
    final id = _uuid.v4();
    final shares = SplitEngine.split(totalMinor: amountMinor, participants: participants.map((id) => SplitInput(personId: id, weight: 1)).toList());
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('expenses', {'id': id, 'title': title.trim(), 'amount_minor': amountMinor, 'currency': currency, 'paid_by': paidBy, 'group_id': groupId, 'created_at': DateTime.now().millisecondsSinceEpoch});
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

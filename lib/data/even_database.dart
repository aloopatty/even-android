import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class EvenDatabase {
  EvenDatabase._();
  static final EvenDatabase instance = EvenDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'even.db'),
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE groups (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, members TEXT NOT NULL,
          created_at INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0)''');
        await db.execute('''CREATE TABLE expenses (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, amount_minor INTEGER NOT NULL,
          currency TEXT NOT NULL DEFAULT 'INR', paid_by TEXT NOT NULL,
          split_method TEXT NOT NULL DEFAULT 'equal',
          group_id TEXT, category TEXT NOT NULL DEFAULT 'Other',
          note TEXT, created_at INTEGER NOT NULL, deleted_at INTEGER,
          FOREIGN KEY(group_id) REFERENCES groups(id))''');
        await db.execute('''CREATE TABLE expense_shares (
          id INTEGER PRIMARY KEY AUTOINCREMENT, expense_id TEXT NOT NULL,
          person_id TEXT NOT NULL, amount_minor INTEGER NOT NULL,
          FOREIGN KEY(expense_id) REFERENCES expenses(id) ON DELETE CASCADE)''');
        await db.execute('''CREATE TABLE settlements (
          id TEXT PRIMARY KEY, from_person TEXT NOT NULL, to_person TEXT NOT NULL,
          amount_minor INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'INR',
          group_id TEXT, note TEXT, created_at INTEGER NOT NULL, deleted_at INTEGER)''');
        await db.execute('''CREATE TABLE recurring_expenses (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, amount_minor INTEGER NOT NULL,
          currency TEXT NOT NULL, frequency TEXT NOT NULL, next_due INTEGER NOT NULL,
          group_id TEXT, active INTEGER NOT NULL DEFAULT 1)''');
        await db.execute('''CREATE TABLE expense_comments (
          id TEXT PRIMARY KEY, expense_id TEXT NOT NULL, author TEXT NOT NULL,
          body TEXT NOT NULL, created_at INTEGER NOT NULL)''');
        await db.execute('''CREATE TABLE activity (
          id TEXT PRIMARY KEY, event_type TEXT NOT NULL, description TEXT NOT NULL,
          created_at INTEGER NOT NULL)''');
        await db.execute('CREATE INDEX idx_expenses_created ON expenses(created_at DESC)');
        await db.execute('CREATE INDEX idx_expenses_group ON expenses(group_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE expenses ADD COLUMN split_method TEXT NOT NULL DEFAULT 'equal'");
        }
        if (oldVersion < 3) {
          await db.execute('CREATE INDEX idx_settlements_active ON settlements(deleted_at, created_at DESC)');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE settlements ADD COLUMN group_id TEXT');
          await db.execute('CREATE INDEX idx_settlements_group ON settlements(group_id, deleted_at, created_at DESC)');
        }
      },
    );
    return _db!;
  }
}

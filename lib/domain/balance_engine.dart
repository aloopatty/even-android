import 'split_engine.dart';

/// Pure ledger math. Positive balances are receivables; negative are debts.
class BalanceEngine {
  const BalanceEngine._();

  static Map<String, int> calculate({
    required List<Map<String, Object?>> expenses,
    required List<Map<String, Object?>> shares,
    required List<Map<String, Object?>> settlements,
  }) {
    final balances = <String, int>{};
    final activeIds = <String>{};
    for (final expense in expenses) {
      if (expense['deleted_at'] != null) continue;
      final id = expense['id'] as String;
      final amount = expense['amount_minor'] as int;
      final payer = (expense['paid_by'] as String).trim();
      if (amount < 0 || payer.isEmpty) throw ArgumentError('Invalid expense ledger row.');
      activeIds.add(id);
      balances[payer] = (balances[payer] ?? 0) + amount;
    }
    for (final share in shares) {
      if (!activeIds.contains(share['expense_id'])) continue;
      final person = (share['person_id'] as String).trim();
      final amount = share['amount_minor'] as int;
      if (person.isEmpty || amount < 0) throw ArgumentError('Invalid expense share.');
      balances[person] = (balances[person] ?? 0) - amount;
    }
    for (final settlement in settlements) {
      if (settlement['deleted_at'] != null) continue;
      final from = (settlement['from_person'] as String).trim();
      final to = (settlement['to_person'] as String).trim();
      final amount = settlement['amount_minor'] as int;
      if (from.isEmpty || to.isEmpty || from == to || amount <= 0) {
        throw ArgumentError('Invalid settlement ledger row.');
      }
      balances[from] = (balances[from] ?? 0) + amount;
      balances[to] = (balances[to] ?? 0) - amount;
    }
    balances.removeWhere((_, value) => value == 0);
    if (balances.values.fold<int>(0, (sum, value) => sum + value) != 0) {
      throw StateError('Ledger is unbalanced. Expense shares must add up to their expense totals.');
    }
    return Map.unmodifiable(balances);
  }

  static List<Transfer> suggestedTransfers(Map<String, int> balances) =>
      SplitEngine.simplify(balances);
}

/// Money is represented as integer minor units (paise/cents), never doubles.
enum SplitMethod { equal, exact, percentage, shares }

class SplitInput {
  const SplitInput({required this.personId, required this.weight});
  final String personId;
  final int weight;
}

class SplitEngine {
  /// Distributes [totalMinor] exactly. Any remainder is assigned one minor
  /// unit at a time in input order, so shares always add up to the total.
  static Map<String, int> split({
    required int totalMinor,
    required List<SplitInput> participants,
    SplitMethod method = SplitMethod.equal,
  }) {
    if (totalMinor < 0) throw ArgumentError('Amount cannot be negative.');
    if (participants.isEmpty) throw ArgumentError('At least one participant is required.');
    if (participants.map((p) => p.personId).toSet().length != participants.length) {
      throw ArgumentError('Participant IDs must be unique.');
    }
    if (participants.any((p) => p.weight <= 0)) {
      throw ArgumentError('Split weights must be positive.');
    }

    final totalWeight = method == SplitMethod.equal
        ? participants.length
        : participants.fold<int>(0, (sum, p) => sum + p.weight);
    final result = <String, int>{};
    var assigned = 0;
    for (final participant in participants) {
      final weight = method == SplitMethod.equal ? 1 : participant.weight;
      final share = (totalMinor * weight) ~/ totalWeight;
      result[participant.personId] = share;
      assigned += share;
    }
    var remainder = totalMinor - assigned;
    for (var i = 0; remainder > 0; i = (i + 1) % participants.length) {
      final id = participants[i].personId;
      result[id] = result[id]! + 1;
      remainder--;
    }
    return result;
  }

  /// Greedy debt simplification. Returns transfers that settle the same net
  /// balances with at most n-1 transfers for n non-zero participants.
  static List<Transfer> simplify(Map<String, int> netBalances) {
    final creditors = <_Balance>[];
    final debtors = <_Balance>[];
    netBalances.forEach((person, amount) {
      if (amount > 0) creditors.add(_Balance(person, amount));
      if (amount < 0) debtors.add(_Balance(person, -amount));
    });
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    final transfers = <Transfer>[];
    var c = 0;
    var d = 0;
    while (c < creditors.length && d < debtors.length) {
      final amount = creditors[c].amount < debtors[d].amount
          ? creditors[c].amount
          : debtors[d].amount;
      if (amount > 0) {
        transfers.add(Transfer(from: debtors[d].person, to: creditors[c].person, amountMinor: amount));
      }
      creditors[c].amount -= amount;
      debtors[d].amount -= amount;
      if (creditors[c].amount == 0) c++;
      if (debtors[d].amount == 0) d++;
    }
    return transfers;
  }
}

class Transfer {
  const Transfer({required this.from, required this.to, required this.amountMinor});
  final String from;
  final String to;
  final int amountMinor;
}

class _Balance {
  _Balance(this.person, this.amount);
  final String person;
  int amount;
}


/// EVEN financial calculation engine.
///
/// All monetary values are stored as integer paise.
/// Never use double for financial calculations.

enum SplitMethod {
  equal,
  exact,
  percentage,
  shares,
}

class SplitInput {
  const SplitInput({
    required this.personId,
    this.weight = 1,
    this.amountMinor,
    this.percentageBasisPoints,
  });

  final String personId;

  /// Used by weighted/share splitting.
  final int weight;

  /// Used by exact/custom amount splitting.
  final int? amountMinor;

  /// Used by percentage splitting.
  /// 10000 basis points = 100%.
  final int? percentageBasisPoints;
}

class SplitEngine {
  static Map<String, int> split({
    required int totalMinor,
    required List<SplitInput> participants,
    SplitMethod method = SplitMethod.equal,
  }) {
    if (totalMinor < 0) {
      throw ArgumentError('Amount cannot be negative.');
    }

    if (participants.isEmpty) {
      throw ArgumentError('At least one participant is required.');
    }

    final ids = participants.map((p) => p.personId).toList();

    if (ids.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Participant IDs cannot be empty.');
    }

    if (ids.toSet().length != ids.length) {
      throw ArgumentError('Participant IDs must be unique.');
    }

    // 1. Equal split
    if (method == SplitMethod.equal) {
      return _allocate(
        totalMinor,
        List.filled(participants.length, 1),
        participants,
      );
    }

    // 2. Exact/custom amount split
    if (method == SplitMethod.exact) {
      final result = <String, int>{};

      for (final p in participants) {
        final amount = p.amountMinor;

        if (amount == null || amount < 0) {
          throw ArgumentError(
            'Every participant needs a valid custom amount.',
          );
        }

        result[p.personId] = amount;
      }

      final sum = result.values.fold<int>(
        0,
        (a, b) => a + b,
      );

      if (sum != totalMinor) {
        throw ArgumentError(
          'Custom amounts must equal the total expense.',
        );
      }

      return result;
    }

    // 3. Percentage split
    if (method == SplitMethod.percentage) {
      final percentages = <int>[];

      for (final p in participants) {
        final percentage = p.percentageBasisPoints;

        if (percentage == null ||
            percentage < 0 ||
            percentage > 10000) {
          throw ArgumentError(
            'Invalid participant percentage.',
          );
        }

        percentages.add(percentage);
      }

      final totalPercentage = percentages.fold<int>(
        0,
        (a, b) => a + b,
      );

      if (totalPercentage != 10000) {
        throw ArgumentError(
          'Percentages must add up to 100%.',
        );
      }

      return _allocate(
        totalMinor,
        percentages,
        participants,
      );
    }

    // 4. Weighted/share split
    if (participants.any((p) => p.weight <= 0)) {
      throw ArgumentError(
        'Share weights must be positive.',
      );
    }

    return _allocate(
      totalMinor,
      participants.map((p) => p.weight).toList(),
      participants,
    );
  }

  /// Allocates money using the largest-remainder method.
  ///
  /// Guarantees that every paise is assigned exactly once.
  /// Ties are resolved using participant input order.
  static Map<String, int> _allocate(
    int totalMinor,
    List<int> weights,
    List<SplitInput> participants,
  ) {
    final totalWeight = weights.fold<BigInt>(
      BigInt.zero,
      (sum, weight) => sum + BigInt.from(weight),
    );

    if (totalWeight <= BigInt.zero) {
      throw ArgumentError('Total weight must be positive.');
    }

    final result = <String, int>{};
    final remainders = <_Remainder>[];

    var assigned = 0;

    for (var i = 0; i < participants.length; i++) {
      final numerator = BigInt.from(totalMinor) *
          BigInt.from(weights[i]);

      final quotient = numerator ~/ totalWeight;
      final remainder = numerator % totalWeight;

      final share = quotient.toInt();

      result[participants[i].personId] = share;
      assigned += share;

      remainders.add(
        _Remainder(i, remainder),
      );
    }

    remainders.sort((a, b) {
      final comparison = b.value.compareTo(a.value);

      if (comparison != 0) return comparison;

      return a.index.compareTo(b.index);
    });

    final remaining = totalMinor - assigned;

    for (var i = 0; i < remaining; i++) {
      final personId =
          participants[remainders[i].index].personId;

      result[personId] = result[personId]! + 1;
    }

    return result;
  }

  /// Simplifies balances into direct settlement transfers.
  ///
  /// Positive balance = money owed to this person.
  /// Negative balance = money this person owes.
  static List<Transfer> simplify(
    Map<String, int> netBalances,
  ) {
    final balanceTotal = netBalances.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );

    if (balanceTotal != 0) {
      throw ArgumentError(
        'Net balances must sum to zero.',
      );
    }

    final creditors = <_Balance>[];
    final debtors = <_Balance>[];

    netBalances.forEach((person, amount) {
      if (amount > 0) {
        creditors.add(_Balance(person, amount));
      } else if (amount < 0) {
        debtors.add(_Balance(person, -amount));
      }
    });

    creditors.sort(
      (a, b) => b.amount.compareTo(a.amount),
    );

    debtors.sort(
      (a, b) => b.amount.compareTo(a.amount),
    );

    final transfers = <Transfer>[];

    var c = 0;
    var d = 0;

    while (c < creditors.length && d < debtors.length) {
      final amount = creditors[c].amount < debtors[d].amount
          ? creditors[c].amount
          : debtors[d].amount;

      if (amount > 0) {
        transfers.add(
          Transfer(
            from: debtors[d].person,
            to: creditors[c].person,
            amountMinor: amount,
          ),
        );
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
  const Transfer({
    required this.from,
    required this.to,
    required this.amountMinor,
  });

  final String from;
  final String to;
  final int amountMinor;
}

class _Balance {
  _Balance(this.person, this.amount);

  final String person;
  int amount;
}

class _Remainder {
  const _Remainder(this.index, this.value);

  final int index;
  final BigInt value;
}

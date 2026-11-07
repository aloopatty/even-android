
import 'package:flutter_test/flutter_test.dart';
import 'package:even/domain/split_engine.dart';

void main() {
  group('EVEN SplitEngine', () {

    // 1. EQUAL SPLITTING
    test('splits equally without losing a paise', () {
      final result = SplitEngine.split(
        totalMinor: 1000,
        participants: const [
          SplitInput(personId: 'a'),
          SplitInput(personId: 'b'),
          SplitInput(personId: 'c'),
        ],
      );

      expect(result.values.toList(), [334, 333, 333]);
      expect(result.values.reduce((a, b) => a + b), 1000);
    });

    // 2. CUSTOM AMOUNT SPLITTING
    test('supports exact custom amounts', () {
      final result = SplitEngine.split(
        totalMinor: 100000,
        method: SplitMethod.exact,
        participants: const [
          SplitInput(personId: 'a', amountMinor: 50000),
          SplitInput(personId: 'b', amountMinor: 30000),
          SplitInput(personId: 'c', amountMinor: 20000),
        ],
      );

      expect(result['a'], 50000);
      expect(result['b'], 30000);
      expect(result['c'], 20000);
    });

    test('rejects incorrect custom amount totals', () {
      expect(
        () => SplitEngine.split(
          totalMinor: 10000,
          method: SplitMethod.exact,
          participants: const [
            SplitInput(personId: 'a', amountMinor: 4000),
            SplitInput(personId: 'b', amountMinor: 4000),
          ],
        ),
        throwsArgumentError,
      );
    });

    // 3. PERCENTAGE SPLITTING
    test('supports percentage splits', () {
      final result = SplitEngine.split(
        totalMinor: 100000,
        method: SplitMethod.percentage,
        participants: const [
          SplitInput(
            personId: 'a',
            percentageBasisPoints: 5000,
          ),
          SplitInput(
            personId: 'b',
            percentageBasisPoints: 3000,
          ),
          SplitInput(
            personId: 'c',
            percentageBasisPoints: 2000,
          ),
        ],
      );

      expect(result['a'], 50000);
      expect(result['b'], 30000);
      expect(result['c'], 20000);
    });

    test('rejects percentages not adding up to 100%', () {
      expect(
        () => SplitEngine.split(
          totalMinor: 10000,
          method: SplitMethod.percentage,
          participants: const [
            SplitInput(
              personId: 'a',
              percentageBasisPoints: 5000,
            ),
            SplitInput(
              personId: 'b',
              percentageBasisPoints: 4000,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    // 4. WEIGHTED / SHARE SPLITTING
    test('supports weighted shares', () {
      final result = SplitEngine.split(
        totalMinor: 100000,
        method: SplitMethod.shares,
        participants: const [
          SplitInput(personId: 'a', weight: 2),
          SplitInput(personId: 'b', weight: 2),
          SplitInput(personId: 'c', weight: 1),
        ],
      );

      expect(result['a'], 40000);
      expect(result['b'], 40000);
      expect(result['c'], 20000);
    });

    test('rejects zero share weights', () {
      expect(
        () => SplitEngine.split(
          totalMinor: 10000,
          method: SplitMethod.shares,
          participants: const [
            SplitInput(personId: 'a', weight: 0),
            SplitInput(personId: 'b', weight: 1),
          ],
        ),
        throwsArgumentError,
      );
    });

    // 5. INPUT VALIDATION
    test('rejects duplicate participants', () {
      expect(
        () => SplitEngine.split(
          totalMinor: 100,
          participants: const [
            SplitInput(personId: 'a'),
            SplitInput(personId: 'a'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative expenses', () {
      expect(
        () => SplitEngine.split(
          totalMinor: -100,
          participants: const [
            SplitInput(personId: 'a'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty participant lists', () {
      expect(
        () => SplitEngine.split(
          totalMinor: 100,
          participants: const [],
        ),
        throwsArgumentError,
      );
    });

    // 6. DEBT SIMPLIFICATION
    test('simplifies debts into direct transfers', () {
      final result = SplitEngine.simplify({
        'A': 7000,
        'B': -3000,
        'C': -4000,
      });

      expect(result.length, 2);
      expect(
        result.fold<int>(
          0,
          (sum, transfer) => sum + transfer.amountMinor,
        ),
        7000,
      );

      expect(result.every((t) => t.to == 'A'), isTrue);
    });

    test('rejects unbalanced net balances', () {
      expect(
        () => SplitEngine.simplify({
          'A': 5000,
          'B': -3000,
        }),
        throwsArgumentError,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:even/domain/split_engine.dart';

void main() {
  group('SplitEngine', () {
    test('splits equally without losing a paise', () {
      final result = SplitEngine.split(totalMinor: 1000, participants: const [
        SplitInput(personId: 'a', weight: 1),
        SplitInput(personId: 'b', weight: 1),
        SplitInput(personId: 'c', weight: 1),
      ]);
      expect(result.values.reduce((a, b) => a + b), 1000);
      expect(result.values.toList(), [334, 333, 333]);
    });

    test('supports weighted splits', () {
      final result = SplitEngine.split(totalMinor: 10000, method: SplitMethod.shares, participants: const [
        SplitInput(personId: 'a', weight: 2),
        SplitInput(personId: 'b', weight: 1),
      ]);
      expect(result['a'], 6667);
      expect(result['b'], 3333);
    });

    test('simplifies debts to direct transfers', () {
      final result = SplitEngine.simplify({'A': 7000, 'B': -3000, 'C': -4000});
      expect(result.length, 2);
      expect(result.fold<int>(0, (sum, t) => sum + t.amountMinor), 7000);
      expect(result.every((t) => t.to == 'A'), isTrue);
    });

    test('rejects duplicate people', () {
      expect(() => SplitEngine.split(totalMinor: 100, participants: const [
        SplitInput(personId: 'a', weight: 1), SplitInput(personId: 'a', weight: 1),
      ]), throwsArgumentError);
    });
  });
}

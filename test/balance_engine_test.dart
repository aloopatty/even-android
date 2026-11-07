import 'package:flutter_test/flutter_test.dart';
import 'package:even/domain/balance_engine.dart';

void main() {
  group('BalanceEngine', () {
    test('calculates balances from payer and individual shares', () {
      final result = BalanceEngine.calculate(
        expenses: [
          {'id': 'e1', 'amount_minor': 10000, 'paid_by': 'A', 'deleted_at': null},
        ],
        shares: [
          {'expense_id': 'e1', 'person_id': 'A', 'amount_minor': 5000},
          {'expense_id': 'e1', 'person_id': 'B', 'amount_minor': 3000},
          {'expense_id': 'e1', 'person_id': 'C', 'amount_minor': 2000},
        ],
        settlements: const [],
      );
      expect(result, {'A': 5000, 'B': -3000, 'C': -2000});
    });

    test('settlement reduces payer debt and receiver credit', () {
      final result = BalanceEngine.calculate(
        expenses: [
          {'id': 'e1', 'amount_minor': 10000, 'paid_by': 'A', 'deleted_at': null},
        ],
        shares: [
          {'expense_id': 'e1', 'person_id': 'A', 'amount_minor': 5000},
          {'expense_id': 'e1', 'person_id': 'B', 'amount_minor': 5000},
        ],
        settlements: [
          {'from_person': 'B', 'to_person': 'A', 'amount_minor': 2000, 'deleted_at': null},
        ],
      );
      expect(result, {'A': 3000, 'B': -3000});
    });

    test('ignores deleted expenses and reversed settlements', () {
      final result = BalanceEngine.calculate(
        expenses: [
          {'id': 'deleted', 'amount_minor': 9000, 'paid_by': 'A', 'deleted_at': 123},
          {'id': 'active', 'amount_minor': 1000, 'paid_by': 'A', 'deleted_at': null},
        ],
        shares: [
          {'expense_id': 'deleted', 'person_id': 'B', 'amount_minor': 9000},
          {'expense_id': 'active', 'person_id': 'A', 'amount_minor': 500},
          {'expense_id': 'active', 'person_id': 'B', 'amount_minor': 500},
        ],
        settlements: [
          {'from_person': 'B', 'to_person': 'A', 'amount_minor': 9000, 'deleted_at': 456},
        ],
      );
      expect(result, {'A': 500, 'B': -500});
    });

    test('rejects ledger whose shares do not equal expenses', () {
      expect(
        () => BalanceEngine.calculate(
          expenses: [
            {'id': 'e1', 'amount_minor': 1000, 'paid_by': 'A', 'deleted_at': null},
          ],
          shares: [
            {'expense_id': 'e1', 'person_id': 'B', 'amount_minor': 900},
          ],
          settlements: const [],
        ),
        throwsStateError,
      );
    });

    test('simplifies debts to the minimum transfer count', () {
      final result = BalanceEngine.suggestedTransfers({
        'A': 7000,
        'B': -3000,
        'C': -4000,
      });
      expect(result, hasLength(2));
      expect(result.fold<int>(0, (sum, transfer) => sum + transfer.amountMinor), 7000);
    });
  });
}

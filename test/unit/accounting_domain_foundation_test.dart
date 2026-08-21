import 'package:test/test.dart';
import 'package:accounting_system/core/money/money.dart';
import 'package:accounting_system/domain/accounting/models/transaction_context.dart';
import 'package:accounting_system/domain/accounting/models/accounting_error.dart';
import 'package:accounting_system/domain/accounting/models/accounting_result.dart';
import 'package:accounting_system/domain/accounting/models/journal_entry_draft.dart';

void main() {
  group('Accounting Domain Foundation Tests (Step 1)', () {
    test('1. TransactionContext and IdempotencyContext immutability & formatting', () {
      final ctx = TransactionContext(
        companyId: 'comp_1',
        userId: 'user_1',
        deviceId: 'dev_1',
        timestampMs: 1700000000000,
      );

      expect(ctx.companyId, equals('comp_1'));
      expect(ctx.userId, equals('user_1'));

      final idempCtx = IdempotencyContext.generate(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale_100',
        deviceId: 'dev_1',
      );

      expect(idempCtx.key, equals('comp_1:sale:sale_100:dev_1'));
    });

    test('2. JournalLineDraft enforces valid debit/credit invariants', () {
      final dr = JournalLineDraft.debit(
        accountId: 'acc_cash',
        amount: Money.fromMinor(100000, 'IQD'),
        description: 'Cash in',
      );

      expect(dr.debitAmount, equals(Money.fromMinor(100000, 'IQD')));
      expect(dr.creditAmount, equals(Money.zero('IQD')));

      final cr = JournalLineDraft.credit(
        accountId: 'acc_sales',
        amount: Money.fromMinor(100000, 'IQD'),
        description: 'Sales revenue',
      );

      expect(cr.debitAmount, equals(Money.zero('IQD')));
      expect(cr.creditAmount, equals(Money.fromMinor(100000, 'IQD')));

      // Reject zero-amount line
      expect(
        () => JournalLineDraft(
          accountId: 'acc_1',
          debitAmount: Money.zero('IQD'),
          creditAmount: Money.zero('IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Reject line with both debit and credit > 0
      expect(
        () => JournalLineDraft(
          accountId: 'acc_1',
          debitAmount: Money.fromMinor(100, 'IQD'),
          creditAmount: Money.fromMinor(100, 'IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Reject negative amounts
      expect(
        () => JournalLineDraft(
          accountId: 'acc_1',
          debitAmount: Money.fromMinor(-100, 'IQD'),
          creditAmount: Money.zero('IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('3. JournalEntryDraft validates balance and calculates running totals', () {
      final entry = JournalEntryDraft(
        id: 'je_1',
        companyId: 'comp_1',
        dateMs: 1700000000000,
        description: 'Sale 1',
        sourceType: 'sale',
        sourceId: 's1',
        currencyCode: 'IQD',
        idempotencyKey: 'key_1',
        createdBy: 'user_1',
        lines: [
          JournalLineDraft.debit(
            accountId: 'acc_cash',
            amount: Money.fromMinor(100000, 'IQD'),
          ),
          JournalLineDraft.credit(
            accountId: 'acc_sales',
            amount: Money.fromMinor(100000, 'IQD'),
          ),
        ],
      );

      expect(entry.totalDebit, equals(Money.fromMinor(100000, 'IQD')));
      expect(entry.totalCredit, equals(Money.fromMinor(100000, 'IQD')));
      expect(entry.isBalanced, isTrue);

      final balanceResult = entry.validateBalance();
      expect(balanceResult.isSuccess, isTrue);
    });

    test('4. JournalEntryDraft detects imbalance and returns ImbalanceError', () {
      final entry = JournalEntryDraft(
        id: 'je_unbalanced',
        companyId: 'comp_1',
        dateMs: 1700000000000,
        description: 'Unbalanced sale',
        sourceType: 'sale',
        sourceId: 's2',
        currencyCode: 'IQD',
        idempotencyKey: 'key_2',
        createdBy: 'user_1',
        lines: [
          JournalLineDraft.debit(
            accountId: 'acc_cash',
            amount: Money.fromMinor(100000, 'IQD'),
          ),
          JournalLineDraft.credit(
            accountId: 'acc_sales',
            amount: Money.fromMinor(80000, 'IQD'),
          ),
        ],
      );

      expect(entry.isBalanced, isFalse);

      final balanceResult = entry.validateBalance();
      expect(balanceResult.isFailure, isTrue);
      expect(balanceResult.error, isA<ImbalanceError>());

      final err = balanceResult.error as ImbalanceError;
      expect(err.totalDebit, equals(Money.fromMinor(100000, 'IQD')));
      expect(err.totalCredit, equals(Money.fromMinor(80000, 'IQD')));
    });

    test('5. AccountingResult functional fold & value access safety', () {
      final successRes = AccountingResult.success(42);
      expect(successRes.isSuccess, isTrue);
      expect(successRes.value, equals(42));
      expect(() => successRes.error, throwsA(isA<StateError>()));

      final failureRes = AccountingResult<int>.failure(
        ValidationError(message: 'Invalid customer', fieldName: 'customerId'),
      );

      expect(failureRes.isFailure, isTrue);
      expect(failureRes.error, isA<ValidationError>());
      expect(() => failureRes.value, throwsA(isA<StateError>()));

      final folded = failureRes.fold(
        onSuccess: (val) => 'Success: $val',
        onFailure: (err) => 'Failed: ${err.code}',
      );

      expect(folded, equals('Failed: VALIDATION_ERROR'));
    });
  });
}

import 'package:test/test.dart';
import 'package:accounting_system/core/money/money.dart';
import 'package:accounting_system/domain/accounting/models/transaction_context.dart';
import 'package:accounting_system/domain/accounting/models/journal_entry_draft.dart';
import 'package:accounting_system/domain/accounting/models/accounting_error.dart';
import 'package:accounting_system/domain/accounting/builder/journal_entry_builder.dart';

void main() {
  late TransactionContext ctx;

  setUp(() {
    ctx = TransactionContext(
      companyId: 'comp_1',
      userId: 'user_1',
      deviceId: 'dev_1',
      timestampMs: 1700000000000,
    );
  });

  group('Journal Entry Builder Unit Tests (Step 2)', () {
    test('1. Valid debit line construction', () {
      final line = JournalLineDraft.debit(
        accountId: 'acc_cash',
        amount: Money.fromMinor(100000, 'IQD'),
      );
      expect(line.debitAmount, equals(Money.fromMinor(100000, 'IQD')));
      expect(line.creditAmount, equals(Money.zero('IQD')));
    });

    test('2. Valid credit line construction', () {
      final line = JournalLineDraft.credit(
        accountId: 'acc_sales',
        amount: Money.fromMinor(100000, 'IQD'),
      );
      expect(line.debitAmount, equals(Money.zero('IQD')));
      expect(line.creditAmount, equals(Money.fromMinor(100000, 'IQD')));
    });

    test('3. Negative debit rejected', () {
      expect(
        () => JournalLineDraft(
          accountId: 'acc_cash',
          debitAmount: Money.fromMinor(-50000, 'IQD'),
          creditAmount: Money.zero('IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('4. Negative credit rejected', () {
      expect(
        () => JournalLineDraft(
          accountId: 'acc_sales',
          debitAmount: Money.zero('IQD'),
          creditAmount: Money.fromMinor(-50000, 'IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('5. Zero-value line rejected', () {
      expect(
        () => JournalLineDraft(
          accountId: 'acc_cash',
          debitAmount: Money.zero('IQD'),
          creditAmount: Money.zero('IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('6. Debit + credit simultaneously rejected', () {
      expect(
        () => JournalLineDraft(
          accountId: 'acc_cash',
          debitAmount: Money.fromMinor(50000, 'IQD'),
          creditAmount: Money.fromMinor(50000, 'IQD'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('7. Balanced two-line entry succeeds', () {
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_1')
          .setDescription('Cash sale')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      expect(res.isSuccess, isTrue);
      final draft = res.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
    });

    test('8. Balanced multi-line entry succeeds', () {
      // 1 Debit (150,000) = 2 Credits (100,000 + 50,000)
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_compound')
          .setDescription('Split sale revenue')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(150000, 'IQD'))
          .addCredit(accountId: 'acc_sales_main', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_sub', amount: Money.fromMinor(50000, 'IQD'))
          .build();

      expect(res.isSuccess, isTrue);
      final draft = res.value;
      expect(draft.lines.length, equals(3));
      expect(draft.totalDebit, equals(Money.fromMinor(150000, 'IQD')));
      expect(draft.totalCredit, equals(Money.fromMinor(150000, 'IQD')));
      expect(draft.isBalanced, isTrue);
    });

    test('9. Unbalanced entry rejected', () {
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_unbalanced')
          .setDescription('Unbalanced entry')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales', amount: Money.fromMinor(80000, 'IQD'))
          .build();

      expect(res.isFailure, isTrue);
      expect(res.error, isA<ImbalanceError>());
    });

    test('10. Empty entry rejected', () {
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_empty')
          .setDescription('Empty entry')
          .build();

      expect(res.isFailure, isTrue);
      expect(res.error, isA<ValidationError>());
    });

    test('11. Single-line entry rejected', () {
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_single')
          .setDescription('Single line entry')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      expect(res.isFailure, isTrue);
      expect(res.error, isA<ValidationError>());
    });

    test('12. Line currency mismatch rejected', () {
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_curr')
          .setDescription('Currency mismatch')
          .setCurrency('IQD')
          .addLine(
            JournalLineDraft.debit(
              accountId: 'acc_cash',
              amount: Money.fromMinor(100000, 'USD'),
            ),
          )
          .addCredit(accountId: 'acc_sales', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      expect(res.isFailure, isTrue);
      expect(res.error, isA<ValidationError>());
    });

    test('21. Same input produces equivalent journal structure', () {
      final res1 = JournalEntryBuilder()
          .setContext(ctx)
          .setId('fixed_id')
          .setSource(sourceType: 'sale', sourceId: 'sale_1')
          .setDescription('Cash sale')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final res2 = JournalEntryBuilder()
          .setContext(ctx)
          .setId('fixed_id')
          .setSource(sourceType: 'sale', sourceId: 'sale_1')
          .setDescription('Cash sale')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      expect(res1.value, equals(res2.value));
    });

    test('22. Journal totals are exact Money values', () {
      final res = JournalEntryBuilder()
          .setContext(ctx)
          .setSource(sourceType: 'sale', sourceId: 'sale_exact')
          .setDescription('Exact money check')
          .addDebit(accountId: 'acc_cash', amount: Money.fromMinor(123456789, 'IQD'))
          .addCredit(accountId: 'acc_sales', amount: Money.fromMinor(123456789, 'IQD'))
          .build();

      final draft = res.value;
      expect(draft.totalDebit, equals(Money.fromMinor(123456789, 'IQD')));
      expect(draft.totalCredit, equals(Money.fromMinor(123456789, 'IQD')));
    });
  });
}

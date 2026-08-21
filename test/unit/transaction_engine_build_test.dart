import 'package:test/test.dart';
import 'package:accounting_system/core/money/money.dart';
import 'package:accounting_system/domain/accounting/models/transaction_context.dart';
import 'package:accounting_system/domain/accounting/models/accounting_error.dart';
import 'package:accounting_system/domain/accounting/models/accounting_result.dart';
import 'package:accounting_system/domain/accounting/models/journal_entry_draft.dart';
import 'package:accounting_system/domain/accounting/repository/journal_entry_repository.dart';

import 'package:accounting_system/domain/accounting/engine/sale_transaction_engine.dart';
import 'package:accounting_system/domain/accounting/engine/purchase_transaction_engine.dart';
import 'package:accounting_system/domain/accounting/engine/customer_payment_engine.dart';
import 'package:accounting_system/domain/accounting/engine/supplier_payment_engine.dart';
import 'package:accounting_system/domain/accounting/engine/expense_engine.dart';
import 'package:accounting_system/domain/accounting/engine/worker_advance_engine.dart';
import 'package:accounting_system/domain/accounting/engine/worker_salary_engine.dart';
import 'package:accounting_system/domain/accounting/engine/owner_withdrawal_engine.dart';
import 'package:accounting_system/domain/accounting/engine/manufacturing_job_engine.dart';

import 'package:accounting_system/domain/accounting/models/transactions/sale_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/purchase_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/customer_payment_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/supplier_payment_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/expense_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/worker_advance_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/worker_salary_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/owner_withdrawal_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/manufacturing_job_transaction.dart';

class StubJournalEntryRepository implements JournalEntryRepository {
  @override
  Future<AccountingResult<dynamic>> persistJournalEntry({
    required JournalEntryDraft draft,
    required TransactionContext context,
  }) async {
    return AccountingResult.success(null);
  }
}

void main() {
  late TransactionContext ctx;
  late StubJournalEntryRepository repo;

  setUp(() {
    ctx = TransactionContext(
      companyId: 'comp_1',
      userId: 'user_1',
      deviceId: 'dev_1',
      timestampMs: 1700000000000,
    );
    repo = StubJournalEntryRepository();
  });

  Money iqd(int minor) => Money.fromMinor(minor, 'IQD');

  // ---------------------------------------------------------------------------
  // SaleTransactionEngine
  // ---------------------------------------------------------------------------
  group('SaleTransactionEngine - buildJournalEntry', () {
    late SaleTransactionEngine engine;

    setUp(() {
      engine = SaleTransactionEngine(
        repository: repo,
        cashAccountId: '1110',
        salesAccountId: '4100',
      );
    });

    test('1. Cash sale: DR Cash totalAmount, CR Sales totalAmount', () {
      final tx = SaleTransaction(
        transactionId: 'sale_1',
        context: ctx,
        idempotencyKey: 'idem_sale_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مبيعات نقدية',
        customerAccountId: '1131_ahmed',
        items: [
          SaleItem(
            description: 'سلعة',
            quantityMinor: 2000,
            unitPrice: Money.fromMinor(50000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.cash,
        cashReceived: Money.fromMinor(100000, 'IQD'),
        creditAmount: Money.zero('IQD'),
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('sale'));
      expect(draft.currencyCode, equals('IQD'));
      expect(draft.description, equals('مبيعات نقدية'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('1110'));
      expect(debitLine.debitAmount, equals(iqd(100000)));
      expect(debitLine.creditAmount, equals(iqd(0)));

      expect(creditLine.accountId, equals('4100'));
      expect(creditLine.creditAmount, equals(iqd(100000)));
      expect(creditLine.debitAmount, equals(iqd(0)));

      expect(draft.totalDebit, equals(iqd(100000)));
      expect(draft.totalCredit, equals(iqd(100000)));
    });

    test('2. Credit sale: DR AccountsReceivable totalAmount, CR Sales totalAmount', () {
      final tx = SaleTransaction(
        transactionId: 'sale_2',
        context: ctx,
        idempotencyKey: 'idem_sale_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مبيعات آجلة',
        customerAccountId: '1131_sara',
        items: [
          SaleItem(
            description: 'خدمة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(200000, 'IQD'),
            totalPrice: Money.fromMinor(200000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.credit,
        cashReceived: Money.zero('IQD'),
        creditAmount: Money.fromMinor(200000, 'IQD'),
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('1131_sara'));
      expect(debitLine.debitAmount, equals(iqd(200000)));

      expect(creditLine.accountId, equals('4100'));
      expect(creditLine.creditAmount, equals(iqd(200000)));
    });

    test('3. Mixed sale: DR Cash cashReceived + DR AR creditAmount, CR Sales totalAmount', () {
      final tx = SaleTransaction(
        transactionId: 'sale_3',
        context: ctx,
        idempotencyKey: 'idem_sale_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مبيعات مختلطة',
        customerAccountId: '1131_omar',
        items: [
          SaleItem(
            description: 'سلعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(150000, 'IQD'),
            totalPrice: Money.fromMinor(150000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.mixed,
        cashReceived: Money.fromMinor(100000, 'IQD'),
        creditAmount: Money.fromMinor(50000, 'IQD'),
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(3));
      expect(draft.isBalanced, isTrue);

      final cashDebit = draft.lines.firstWhere(
        (l) => l.accountId == '1110' && l.debitAmount.isPositive,
      );
      final arDebit = draft.lines.firstWhere(
        (l) => l.accountId == '1131_omar' && l.debitAmount.isPositive,
      );
      final salesCredit = draft.lines.firstWhere(
        (l) => l.accountId == '4100' && l.creditAmount.isPositive,
      );

      expect(cashDebit.debitAmount, equals(iqd(100000)));
      expect(arDebit.debitAmount, equals(iqd(50000)));
      expect(salesCredit.creditAmount, equals(iqd(150000)));

      expect(draft.totalDebit, equals(iqd(150000)));
      expect(draft.totalCredit, equals(iqd(150000)));
    });

    test('4. Mixed sale with mismatched amounts returns ValidationError', () {
      final tx = SaleTransaction(
        transactionId: 'sale_4',
        context: ctx,
        idempotencyKey: 'idem_sale_4',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مبيعات مختلطة غير متطابقة',
        customerAccountId: '1131_omar',
        items: [
          SaleItem(
            description: 'سلعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(200000, 'IQD'),
            totalPrice: Money.fromMinor(200000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.mixed,
        cashReceived: Money.fromMinor(100000, 'IQD'),
        creditAmount: Money.fromMinor(50000, 'IQD'),
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<ValidationError>());
    });
  });

  // ---------------------------------------------------------------------------
  // PurchaseTransactionEngine
  // ---------------------------------------------------------------------------
  group('PurchaseTransactionEngine - buildJournalEntry', () {
    late PurchaseTransactionEngine engine;

    setUp(() {
      engine = PurchaseTransactionEngine(
        repository: repo,
        cashAccountId: '1110',
      );
    });

    test('5. Cash purchase: DR Target totalAmount, CR Cash totalAmount', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_1',
        context: ctx,
        idempotencyKey: 'idem_pur_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'شراء نقدي',
        supplierAccountId: '2110_ali',
        targetAccountId: '1140',
        items: [
          PurchaseItem(
            description: 'مواد خام',
            quantityMinor: 5000,
            unitPrice: Money.fromMinor(30000, 'IQD'),
            totalPrice: Money.fromMinor(150000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.cash,
        cashPaid: Money.fromMinor(150000, 'IQD'),
        creditAmount: Money.zero('IQD'),
        accountingNature: PurchaseAccountingNature.inventory,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('purchase'));
      expect(draft.currencyCode, equals('IQD'));
      expect(draft.description, equals('شراء نقدي'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('1140'));
      expect(debitLine.debitAmount, equals(iqd(150000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(150000)));

      expect(draft.totalDebit, equals(iqd(150000)));
      expect(draft.totalCredit, equals(iqd(150000)));
    });

    test('6. Credit purchase: DR Target totalAmount, CR AccountsPayable totalAmount', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_2',
        context: ctx,
        idempotencyKey: 'idem_pur_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'شراء آجل',
        supplierAccountId: '2110_khalid',
        targetAccountId: '5100',
        items: [
          PurchaseItem(
            description: 'خامات',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(300000, 'IQD'),
            totalPrice: Money.fromMinor(300000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.credit,
        cashPaid: Money.zero('IQD'),
        creditAmount: Money.fromMinor(300000, 'IQD'),
        accountingNature: PurchaseAccountingNature.materials,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('5100'));
      expect(debitLine.debitAmount, equals(iqd(300000)));

      expect(creditLine.accountId, equals('2110_khalid'));
      expect(creditLine.creditAmount, equals(iqd(300000)));
    });

    test('7. Mixed purchase: DR Target totalAmount, CR Cash cashPaid + CR AP creditAmount', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_3',
        context: ctx,
        idempotencyKey: 'idem_pur_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'شراء مختلط',
        supplierAccountId: '2110_yusuf',
        targetAccountId: '1140',
        items: [
          PurchaseItem(
            description: 'بضاعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(400000, 'IQD'),
            totalPrice: Money.fromMinor(400000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.mixed,
        cashPaid: Money.fromMinor(250000, 'IQD'),
        creditAmount: Money.fromMinor(150000, 'IQD'),
        accountingNature: PurchaseAccountingNature.inventory,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(3));
      expect(draft.isBalanced, isTrue);

      final debitLine = draft.lines.firstWhere(
        (l) => l.accountId == '1140' && l.debitAmount.isPositive,
      );
      final cashCredit = draft.lines.firstWhere(
        (l) => l.accountId == '1110' && l.creditAmount.isPositive,
      );
      final apCredit = draft.lines.firstWhere(
        (l) => l.accountId == '2110_yusuf' && l.creditAmount.isPositive,
      );

      expect(debitLine.debitAmount, equals(iqd(400000)));
      expect(cashCredit.creditAmount, equals(iqd(250000)));
      expect(apCredit.creditAmount, equals(iqd(150000)));

      expect(draft.totalDebit, equals(iqd(400000)));
      expect(draft.totalCredit, equals(iqd(400000)));
    });

    test('8. Mixed purchase with mismatched amounts returns ValidationError', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_4',
        context: ctx,
        idempotencyKey: 'idem_pur_4',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'شراء مختلط غير متطابق',
        supplierAccountId: '2110_yusuf',
        targetAccountId: '1140',
        items: [
          PurchaseItem(
            description: 'بضاعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(400000, 'IQD'),
            totalPrice: Money.fromMinor(400000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.mixed,
        cashPaid: Money.fromMinor(200000, 'IQD'),
        creditAmount: Money.fromMinor(100000, 'IQD'),
        accountingNature: PurchaseAccountingNature.inventory,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<ValidationError>());
    });
  });

  // ---------------------------------------------------------------------------
  // CustomerPaymentEngine
  // ---------------------------------------------------------------------------
  group('CustomerPaymentEngine - buildJournalEntry', () {
    late CustomerPaymentEngine engine;

    setUp(() {
      engine = CustomerPaymentEngine(
        repository: repo,
        cashAccountId: '1110',
        bankAccountId: '1120',
      );
    });

    test('9. Cash payment: DR Cash, CR AccountsReceivable', () {
      final tx = CustomerPaymentTransaction(
        transactionId: 'cp_1',
        context: ctx,
        idempotencyKey: 'idem_cp_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'تحصيل نقدي من العميل',
        customerId: 'cust_1',
        customerAccountId: '1131_ahmed',
        amount: Money.fromMinor(150000, 'IQD'),
        paymentMethod: CustomerPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('customer_payment'));
      expect(draft.currencyCode, equals('IQD'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('1110'));
      expect(debitLine.debitAmount, equals(iqd(150000)));

      expect(creditLine.accountId, equals('1131_ahmed'));
      expect(creditLine.creditAmount, equals(iqd(150000)));
    });

    test('10. Bank payment: DR Bank, CR AccountsReceivable', () {
      final tx = CustomerPaymentTransaction(
        transactionId: 'cp_2',
        context: ctx,
        idempotencyKey: 'idem_cp_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'تحويل بنكي من العميل',
        customerId: 'cust_2',
        customerAccountId: '1131_sara',
        amount: Money.fromMinor(300000, 'IQD'),
        paymentMethod: CustomerPaymentMethod.bank,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('1120'));
      expect(debitLine.debitAmount, equals(iqd(300000)));

      expect(creditLine.accountId, equals('1131_sara'));
      expect(creditLine.creditAmount, equals(iqd(300000)));
    });
  });

  // ---------------------------------------------------------------------------
  // SupplierPaymentEngine
  // ---------------------------------------------------------------------------
  group('SupplierPaymentEngine - buildJournalEntry', () {
    late SupplierPaymentEngine engine;

    setUp(() {
      engine = SupplierPaymentEngine(
        repository: repo,
        cashAccountId: '1110',
        bankAccountId: '1120',
      );
    });

    test('11. Cash payment: DR AccountsPayable, CR Cash', () {
      final tx = SupplierPaymentTransaction(
        transactionId: 'sp_1',
        context: ctx,
        idempotencyKey: 'idem_sp_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'دفع نقدي للمورد',
        supplierId: 'sup_1',
        supplierAccountId: '2110_ali',
        amount: Money.fromMinor(200000, 'IQD'),
        paymentMethod: SupplierPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('supplier_payment'));
      expect(draft.currencyCode, equals('IQD'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('2110_ali'));
      expect(debitLine.debitAmount, equals(iqd(200000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(200000)));
    });

    test('12. Bank payment: DR AccountsPayable, CR Bank', () {
      final tx = SupplierPaymentTransaction(
        transactionId: 'sp_2',
        context: ctx,
        idempotencyKey: 'idem_sp_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'تحويل بنكي للمورد',
        supplierId: 'sup_2',
        supplierAccountId: '2110_khalid',
        amount: Money.fromMinor(500000, 'IQD'),
        paymentMethod: SupplierPaymentMethod.bank,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('2110_khalid'));
      expect(debitLine.debitAmount, equals(iqd(500000)));

      expect(creditLine.accountId, equals('1120'));
      expect(creditLine.creditAmount, equals(iqd(500000)));
    });
  });

  // ---------------------------------------------------------------------------
  // ExpenseEngine
  // ---------------------------------------------------------------------------
  group('ExpenseEngine - buildJournalEntry', () {
    late ExpenseEngine engine;

    setUp(() {
      engine = ExpenseEngine(repository: repo);
    });

    test('13. Expense: DR Expense account, CR Cash account', () {
      final tx = ExpenseTransaction(
        transactionId: 'exp_1',
        context: ctx,
        idempotencyKey: 'idem_exp_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'دفع إيجار',
        expenseCategoryId: 'cat_rent',
        expenseAccountAccountId: '6100',
        cashAccountAccountId: '1110',
        amount: Money.fromMinor(100000, 'IQD'),
        paymentMethod: ExpensePaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('expense'));
      expect(draft.currencyCode, equals('IQD'));
      expect(draft.description, equals('دفع إيجار'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('6100'));
      expect(debitLine.debitAmount, equals(iqd(100000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(100000)));

      expect(draft.totalDebit, equals(iqd(100000)));
      expect(draft.totalCredit, equals(iqd(100000)));
    });
  });

  // ---------------------------------------------------------------------------
  // WorkerAdvanceEngine
  // ---------------------------------------------------------------------------
  group('WorkerAdvanceEngine - buildJournalEntry', () {
    late WorkerAdvanceEngine engine;

    setUp(() {
      engine = WorkerAdvanceEngine(repository: repo);
    });

    test('14. Worker advance: DR Worker account, CR Cash account', () {
      final tx = WorkerAdvanceTransaction(
        transactionId: 'wa_1',
        context: ctx,
        idempotencyKey: 'idem_wa_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'سلفة عامل',
        workerId: 'worker_1',
        workerAccountId: '2200_ahmed',
        cashAccountAccountId: '1110',
        amount: Money.fromMinor(50000, 'IQD'),
        paymentMethod: WorkerAdvancePaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('worker_advance'));
      expect(draft.currencyCode, equals('IQD'));
      expect(draft.description, equals('سلفة عامل'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('2200_ahmed'));
      expect(debitLine.debitAmount, equals(iqd(50000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(50000)));

      expect(draft.totalDebit, equals(iqd(50000)));
      expect(draft.totalCredit, equals(iqd(50000)));
    });
  });

  // ---------------------------------------------------------------------------
  // WorkerSalaryEngine
  // ---------------------------------------------------------------------------
  group('WorkerSalaryEngine - buildJournalEntry', () {
    late WorkerSalaryEngine engine;

    setUp(() {
      engine = WorkerSalaryEngine(
        repository: repo,
        directLaborAccountId: '5200',
      );
    });

    test('15. Salary without deduction: DR DirectLabor grossSalary, CR Cash netPayment', () {
      final tx = WorkerSalaryTransaction(
        transactionId: 'ws_1',
        context: ctx,
        idempotencyKey: 'idem_ws_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'رواتب شهرية',
        workerId: 'worker_1',
        workerAccountId: '2200_ahmed',
        cashAccountAccountId: '1110',
        grossSalary: Money.fromMinor(300000, 'IQD'),
        advanceDeduction: Money.zero('IQD'),
        netPayment: Money.fromMinor(300000, 'IQD'),
        paymentMethod: WorkerSalaryPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('worker_salary'));
      expect(draft.currencyCode, equals('IQD'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('5200'));
      expect(debitLine.debitAmount, equals(iqd(300000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(300000)));

      expect(draft.totalDebit, equals(iqd(300000)));
      expect(draft.totalCredit, equals(iqd(300000)));
    });

    test('16. Salary with deduction: DR DirectLabor, CR Worker advanceDeduction, CR Cash netPayment', () {
      final tx = WorkerSalaryTransaction(
        transactionId: 'ws_2',
        context: ctx,
        idempotencyKey: 'idem_ws_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'رواتب مع سلفة',
        workerId: 'worker_1',
        workerAccountId: '2200_ahmed',
        cashAccountAccountId: '1110',
        grossSalary: Money.fromMinor(300000, 'IQD'),
        advanceDeduction: Money.fromMinor(50000, 'IQD'),
        netPayment: Money.fromMinor(250000, 'IQD'),
        paymentMethod: WorkerSalaryPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(3));
      expect(draft.isBalanced, isTrue);

      final debitLine = draft.lines.firstWhere(
        (l) => l.accountId == '5200' && l.debitAmount.isPositive,
      );
      final workerCredit = draft.lines.firstWhere(
        (l) => l.accountId == '2200_ahmed' && l.creditAmount.isPositive,
      );
      final cashCredit = draft.lines.firstWhere(
        (l) => l.accountId == '1110' && l.creditAmount.isPositive,
      );

      expect(debitLine.debitAmount, equals(iqd(300000)));
      expect(workerCredit.creditAmount, equals(iqd(50000)));
      expect(cashCredit.creditAmount, equals(iqd(250000)));

      expect(draft.totalDebit, equals(iqd(300000)));
      expect(draft.totalCredit, equals(iqd(300000)));
    });

    test('17. Salary with mismatched amounts returns ValidationError', () {
      final tx = WorkerSalaryTransaction(
        transactionId: 'ws_3',
        context: ctx,
        idempotencyKey: 'idem_ws_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'رواتب غير متطابقة',
        workerId: 'worker_1',
        workerAccountId: '2200_ahmed',
        cashAccountAccountId: '1110',
        grossSalary: Money.fromMinor(300000, 'IQD'),
        advanceDeduction: Money.fromMinor(100000, 'IQD'),
        netPayment: Money.fromMinor(150000, 'IQD'),
        paymentMethod: WorkerSalaryPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<ValidationError>());
    });
  });

  // ---------------------------------------------------------------------------
  // OwnerWithdrawalEngine
  // ---------------------------------------------------------------------------
  group('OwnerWithdrawalEngine - buildJournalEntry', () {
    late OwnerWithdrawalEngine engine;

    setUp(() {
      engine = OwnerWithdrawalEngine(repository: repo);
    });

    test('18. Owner withdrawal: DR Drawings, CR Cash', () {
      final tx = OwnerWithdrawalTransaction(
        transactionId: 'ow_1',
        context: ctx,
        idempotencyKey: 'idem_ow_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'سحب مالك',
        ownerDrawingAccountId: '3300',
        cashAccountAccountId: '1110',
        amount: Money.fromMinor(100000, 'IQD'),
        paymentMethod: OwnerWithdrawalPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('owner_withdrawal'));
      expect(draft.currencyCode, equals('IQD'));
      expect(draft.description, equals('سحب مالك'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('3300'));
      expect(debitLine.debitAmount, equals(iqd(100000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(100000)));

      expect(draft.totalDebit, equals(iqd(100000)));
      expect(draft.totalCredit, equals(iqd(100000)));
    });
  });

  // ---------------------------------------------------------------------------
  // ManufacturingJobEngine
  // ---------------------------------------------------------------------------
  group('ManufacturingJobEngine - buildJournalEntry', () {
    late ManufacturingJobEngine engine;

    setUp(() {
      engine = ManufacturingJobEngine(repository: repo);
    });

    test('19. Manufacturing job: DR Target account, CR Cash account', () {
      final tx = ManufacturingJobTransaction(
        transactionId: 'mj_1',
        context: ctx,
        idempotencyKey: 'idem_mj_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'عمل تصنيعي',
        workshopId: 'ws_1',
        workType: 'تشطيب',
        scenario: ManufacturingScenario.external,
        accountingTreatment: ManufacturingAccountingTreatment.costOfManufacturing,
        targetAccountId: '7300',
        cashAccountAccountId: '1110',
        totalCost: Money.fromMinor(250000, 'IQD'),
        paymentMethod: ManufacturingPaymentMethod.cash,
      );

      final result = engine.buildJournalEntry(tx);
      expect(result.isSuccess, isTrue);

      final draft = result.value;
      expect(draft.lines.length, equals(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.sourceType, equals('manufacturing'));
      expect(draft.currencyCode, equals('IQD'));
      expect(draft.description, equals('عمل تصنيعي'));

      final debitLine = draft.lines.firstWhere((l) => l.debitAmount.isPositive);
      final creditLine = draft.lines.firstWhere((l) => l.creditAmount.isPositive);

      expect(debitLine.accountId, equals('7300'));
      expect(debitLine.debitAmount, equals(iqd(250000)));

      expect(creditLine.accountId, equals('1110'));
      expect(creditLine.creditAmount, equals(iqd(250000)));

      expect(draft.totalDebit, equals(iqd(250000)));
      expect(draft.totalCredit, equals(iqd(250000)));
    });
  });
}

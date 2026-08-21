import 'package:test/test.dart';
import 'package:accounting_system/core/money/money.dart';
import 'package:accounting_system/domain/accounting/models/transaction_context.dart';

import 'package:accounting_system/domain/accounting/models/transactions/sale_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/purchase_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/customer_payment_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/supplier_payment_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/expense_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/worker_advance_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/worker_salary_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/owner_withdrawal_transaction.dart';
import 'package:accounting_system/domain/accounting/models/transactions/manufacturing_job_transaction.dart';

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

  Money iqd(int minor) => Money.fromMinor(minor, 'IQD');

  // ---------------------------------------------------------------------------
  // SaleTransaction
  // ---------------------------------------------------------------------------
  group('SaleTransaction Tests', () {
    test('1. totalAmount computed correctly from items', () {
      final tx = SaleTransaction(
        transactionId: 'sale_1',
        context: ctx,
        idempotencyKey: 'idem_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مبيعات',
        customerAccountId: '1131_ahmed',
        items: [
          SaleItem(
            description: 'سلعة',
            quantityMinor: 2000,
            unitPrice: Money.fromMinor(50000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
          ),
          SaleItem(
            description: 'خدمة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(200000, 'IQD'),
            totalPrice: Money.fromMinor(200000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.cash,
        cashReceived: Money.fromMinor(300000, 'IQD'),
        creditAmount: Money.zero('IQD'),
      );

      expect(tx.totalAmount, equals(iqd(300000)));
    });

    test('2. totalAmount with single item', () {
      final tx = SaleTransaction(
        transactionId: 'sale_2',
        context: ctx,
        idempotencyKey: 'idem_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مبيعات فردية',
        customerAccountId: '1131_sara',
        items: [
          SaleItem(
            description: 'بضاعة',
            quantityMinor: 5000,
            unitPrice: Money.fromMinor(10000, 'IQD'),
            totalPrice: Money.fromMinor(50000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.cash,
        cashReceived: Money.fromMinor(50000, 'IQD'),
        creditAmount: Money.zero('IQD'),
      );

      expect(tx.totalAmount, equals(iqd(50000)));
    });

    test('3. sourceType returns sale', () {
      final tx = SaleTransaction(
        transactionId: 'sale_3',
        context: ctx,
        idempotencyKey: 'idem_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'اختبار المصدر',
        customerAccountId: '1131_omar',
        items: [
          SaleItem(
            description: 'سلعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(100000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.cash,
        cashReceived: Money.fromMinor(100000, 'IQD'),
        creditAmount: Money.zero('IQD'),
      );

      expect(tx.sourceType, equals('sale'));
    });

    test('4. Immutability: items list is unmodifiable', () {
      final items = [
            SaleItem(
            description: 'سلعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(100000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
        ),
      ];

      final tx = SaleTransaction(
        transactionId: 'sale_4',
        context: ctx,
        idempotencyKey: 'idem_4',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'اختبار عدم التغيير',
        customerAccountId: '1131_ahmed',
        items: items,
        paymentType: SalePaymentType.cash,
        cashReceived: Money.fromMinor(100000, 'IQD'),
        creditAmount: Money.zero('IQD'),
      );

      expect(tx.items.length, equals(1));
      expect(tx.items, equals(items));
    });

    test('5. Inherited fields are accessible', () {
      final tx = SaleTransaction(
        transactionId: 'sale_5',
        context: ctx,
        idempotencyKey: 'idem_5',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'اختبار الحقول',
        customerAccountId: '1131_ahmed',
        items: [
          SaleItem(
            description: 'سلعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(100000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
          ),
        ],
        paymentType: SalePaymentType.credit,
        cashReceived: Money.zero('IQD'),
        creditAmount: Money.fromMinor(100000, 'IQD'),
      );

      expect(tx.transactionId, equals('sale_5'));
      expect(tx.idempotencyKey, equals('idem_5'));
      expect(tx.dateMs, equals(1700000000000));
      expect(tx.currencyCode, equals('IQD'));
      expect(tx.companyId, equals('comp_1'));
      expect(tx.userId, equals('user_1'));
      expect(tx.deviceId, equals('dev_1'));
      expect(tx.customerAccountId, equals('1131_ahmed'));
      expect(tx.paymentType, equals(SalePaymentType.credit));
    });
  });

  // ---------------------------------------------------------------------------
  // PurchaseTransaction
  // ---------------------------------------------------------------------------
  group('PurchaseTransaction Tests', () {
    test('6. totalAmount computed correctly from items', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_1',
        context: ctx,
        idempotencyKey: 'idem_pur_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'شراء',
        supplierAccountId: '2110_ali',
        targetAccountId: '1140',
        items: [
          PurchaseItem(
            description: 'خام',
            quantityMinor: 3000,
            unitPrice: Money.fromMinor(20000, 'IQD'),
            totalPrice: Money.fromMinor(60000, 'IQD'),
          ),
          PurchaseItem(
            description: 'مادة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(140000, 'IQD'),
            totalPrice: Money.fromMinor(140000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.cash,
        cashPaid: Money.fromMinor(200000, 'IQD'),
        creditAmount: Money.zero('IQD'),
        accountingNature: PurchaseAccountingNature.inventory,
      );

      expect(tx.totalAmount, equals(iqd(200000)));
    });

    test('7. totalAmount with single item', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_2',
        context: ctx,
        idempotencyKey: 'idem_pur_2',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'شراء فردي',
        supplierAccountId: '2110_khalid',
        targetAccountId: '5100',
        items: [
          PurchaseItem(
            description: 'مادة خام',
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

      expect(tx.totalAmount, equals(iqd(300000)));
    });

    test('8. sourceType returns purchase', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_3',
        context: ctx,
        idempotencyKey: 'idem_pur_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'اختبار المصدر',
        supplierAccountId: '2110_ali',
        targetAccountId: '1140',
        items: [
          PurchaseItem(
            description: 'بضاعة',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(100000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.cash,
        cashPaid: Money.fromMinor(100000, 'IQD'),
        creditAmount: Money.zero('IQD'),
        accountingNature: PurchaseAccountingNature.inventory,
      );

      expect(tx.sourceType, equals('purchase'));
    });

    test('9. Inherited fields are accessible', () {
      final tx = PurchaseTransaction(
        transactionId: 'pur_4',
        context: ctx,
        idempotencyKey: 'idem_pur_4',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'اختبار الحقول',
        supplierAccountId: '2110_khalid',
        targetAccountId: '5100',
        items: [
          PurchaseItem(
            description: 'خام',
            quantityMinor: 1000,
            unitPrice: Money.fromMinor(100000, 'IQD'),
            totalPrice: Money.fromMinor(100000, 'IQD'),
          ),
        ],
        paymentType: PurchasePaymentType.mixed,
        cashPaid: Money.fromMinor(50000, 'IQD'),
        creditAmount: Money.fromMinor(50000, 'IQD'),
        accountingNature: PurchaseAccountingNature.materials,
      );

      expect(tx.transactionId, equals('pur_4'));
      expect(tx.idempotencyKey, equals('idem_pur_4'));
      expect(tx.dateMs, equals(1700000000000));
      expect(tx.currencyCode, equals('IQD'));
      expect(tx.companyId, equals('comp_1'));
      expect(tx.supplierAccountId, equals('2110_khalid'));
      expect(tx.targetAccountId, equals('5100'));
      expect(tx.paymentType, equals(PurchasePaymentType.mixed));
      expect(tx.accountingNature, equals(PurchaseAccountingNature.materials));
    });
  });

  // ---------------------------------------------------------------------------
  // CustomerPaymentTransaction
  // ---------------------------------------------------------------------------
  group('CustomerPaymentTransaction Tests', () {
    test('10. sourceType returns customer_payment', () {
      final tx = CustomerPaymentTransaction(
        transactionId: 'cp_1',
        context: ctx,
        idempotencyKey: 'idem_cp_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'تحصيل من العميل',
        customerId: 'cust_1',
        customerAccountId: '1131_ahmed',
        amount: Money.fromMinor(100000, 'IQD'),
        paymentMethod: CustomerPaymentMethod.cash,
      );

      expect(tx.sourceType, equals('customer_payment'));
    });

    test('11. Fields are accessible correctly', () {
      final tx = CustomerPaymentTransaction(
        transactionId: 'cp_2',
        context: ctx,
        idempotencyKey: 'idem_cp_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'تحويل بنكي',
        customerId: 'cust_2',
        customerAccountId: '1131_sara',
        amount: Money.fromMinor(250000, 'IQD'),
        paymentMethod: CustomerPaymentMethod.bank,
      );

      expect(tx.transactionId, equals('cp_2'));
      expect(tx.customerId, equals('cust_2'));
      expect(tx.customerAccountId, equals('1131_sara'));
      expect(tx.amount, equals(iqd(250000)));
      expect(tx.paymentMethod, equals(CustomerPaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });

    test('12. Identity equality holds for same instance', () {
      final tx = CustomerPaymentTransaction(
        transactionId: 'cp_3',
        context: ctx,
        idempotencyKey: 'idem_cp_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'دفع',
        customerId: 'cust_1',
        customerAccountId: '1131_ahmed',
        amount: Money.fromMinor(100000, 'IQD'),
        paymentMethod: CustomerPaymentMethod.cash,
      );

      expect(tx == tx, isTrue);
      expect(tx.hashCode, equals(tx.hashCode));
    });
  });

  // ---------------------------------------------------------------------------
  // SupplierPaymentTransaction
  // ---------------------------------------------------------------------------
  group('SupplierPaymentTransaction Tests', () {
    test('13. sourceType returns supplier_payment', () {
      final tx = SupplierPaymentTransaction(
        transactionId: 'sp_1',
        context: ctx,
        idempotencyKey: 'idem_sp_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'دفع للمورد',
        supplierId: 'sup_1',
        supplierAccountId: '2110_ali',
        amount: Money.fromMinor(150000, 'IQD'),
        paymentMethod: SupplierPaymentMethod.cash,
      );

      expect(tx.sourceType, equals('supplier_payment'));
    });

    test('14. Fields are accessible correctly', () {
      final tx = SupplierPaymentTransaction(
        transactionId: 'sp_2',
        context: ctx,
        idempotencyKey: 'idem_sp_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'تحويل للمورد',
        supplierId: 'sup_2',
        supplierAccountId: '2110_khalid',
        amount: Money.fromMinor(400000, 'IQD'),
        paymentMethod: SupplierPaymentMethod.bank,
      );

      expect(tx.transactionId, equals('sp_2'));
      expect(tx.supplierId, equals('sup_2'));
      expect(tx.supplierAccountId, equals('2110_khalid'));
      expect(tx.amount, equals(iqd(400000)));
      expect(tx.paymentMethod, equals(SupplierPaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });
  });

  // ---------------------------------------------------------------------------
  // ExpenseTransaction
  // ---------------------------------------------------------------------------
  group('ExpenseTransaction Tests', () {
    test('15. sourceType returns expense', () {
      final tx = ExpenseTransaction(
        transactionId: 'exp_1',
        context: ctx,
        idempotencyKey: 'idem_exp_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'مصروف',
        expenseCategoryId: 'cat_rent',
        expenseAccountAccountId: '6100',
        cashAccountAccountId: '1110',
        amount: Money.fromMinor(100000, 'IQD'),
        paymentMethod: ExpensePaymentMethod.cash,
      );

      expect(tx.sourceType, equals('expense'));
    });

    test('16. Fields are accessible correctly', () {
      final tx = ExpenseTransaction(
        transactionId: 'exp_2',
        context: ctx,
        idempotencyKey: 'idem_exp_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'فواتير كهرباء',
        expenseCategoryId: 'cat_utilities',
        expenseAccountAccountId: '6200',
        cashAccountAccountId: '1120',
        amount: Money.fromMinor(75000, 'IQD'),
        paymentMethod: ExpensePaymentMethod.bank,
      );

      expect(tx.transactionId, equals('exp_2'));
      expect(tx.expenseCategoryId, equals('cat_utilities'));
      expect(tx.expenseAccountAccountId, equals('6200'));
      expect(tx.cashAccountAccountId, equals('1120'));
      expect(tx.amount, equals(iqd(75000)));
      expect(tx.paymentMethod, equals(ExpensePaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });
  });

  // ---------------------------------------------------------------------------
  // WorkerAdvanceTransaction
  // ---------------------------------------------------------------------------
  group('WorkerAdvanceTransaction Tests', () {
    test('17. sourceType returns worker_advance', () {
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

      expect(tx.sourceType, equals('worker_advance'));
    });

    test('18. Fields are accessible correctly', () {
      final tx = WorkerAdvanceTransaction(
        transactionId: 'wa_2',
        context: ctx,
        idempotencyKey: 'idem_wa_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'سلفة بنكية',
        workerId: 'worker_2',
        workerAccountId: '2200_omar',
        cashAccountAccountId: '1120',
        amount: Money.fromMinor(80000, 'IQD'),
        paymentMethod: WorkerAdvancePaymentMethod.bank,
      );

      expect(tx.transactionId, equals('wa_2'));
      expect(tx.workerId, equals('worker_2'));
      expect(tx.workerAccountId, equals('2200_omar'));
      expect(tx.cashAccountAccountId, equals('1120'));
      expect(tx.amount, equals(iqd(80000)));
      expect(tx.paymentMethod, equals(WorkerAdvancePaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });
  });

  // ---------------------------------------------------------------------------
  // WorkerSalaryTransaction
  // ---------------------------------------------------------------------------
  group('WorkerSalaryTransaction Tests', () {
    test('19. sourceType returns worker_salary', () {
      final tx = WorkerSalaryTransaction(
        transactionId: 'ws_1',
        context: ctx,
        idempotencyKey: 'idem_ws_1',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'راتب شهري',
        workerId: 'worker_1',
        workerAccountId: '2200_ahmed',
        cashAccountAccountId: '1110',
        grossSalary: Money.fromMinor(300000, 'IQD'),
        advanceDeduction: Money.zero('IQD'),
        netPayment: Money.fromMinor(300000, 'IQD'),
        paymentMethod: WorkerSalaryPaymentMethod.cash,
      );

      expect(tx.sourceType, equals('worker_salary'));
    });

    test('20. Fields are accessible correctly', () {
      final tx = WorkerSalaryTransaction(
        transactionId: 'ws_2',
        context: ctx,
        idempotencyKey: 'idem_ws_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'راتب مع سلفة',
        workerId: 'worker_2',
        workerAccountId: '2200_omar',
        cashAccountAccountId: '1120',
        grossSalary: Money.fromMinor(500000, 'IQD'),
        advanceDeduction: Money.fromMinor(100000, 'IQD'),
        netPayment: Money.fromMinor(400000, 'IQD'),
        paymentMethod: WorkerSalaryPaymentMethod.bank,
      );

      expect(tx.transactionId, equals('ws_2'));
      expect(tx.workerId, equals('worker_2'));
      expect(tx.workerAccountId, equals('2200_omar'));
      expect(tx.cashAccountAccountId, equals('1120'));
      expect(tx.grossSalary, equals(iqd(500000)));
      expect(tx.advanceDeduction, equals(iqd(100000)));
      expect(tx.netPayment, equals(iqd(400000)));
      expect(tx.paymentMethod, equals(WorkerSalaryPaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });
  });

  // ---------------------------------------------------------------------------
  // OwnerWithdrawalTransaction
  // ---------------------------------------------------------------------------
  group('OwnerWithdrawalTransaction Tests', () {
    test('21. sourceType returns owner_withdrawal', () {
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

      expect(tx.sourceType, equals('owner_withdrawal'));
    });

    test('22. Fields are accessible correctly', () {
      final tx = OwnerWithdrawalTransaction(
        transactionId: 'ow_2',
        context: ctx,
        idempotencyKey: 'idem_ow_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'سحب بنكي',
        ownerDrawingAccountId: '3300',
        cashAccountAccountId: '1120',
        amount: Money.fromMinor(200000, 'IQD'),
        paymentMethod: OwnerWithdrawalPaymentMethod.bank,
      );

      expect(tx.transactionId, equals('ow_2'));
      expect(tx.ownerDrawingAccountId, equals('3300'));
      expect(tx.cashAccountAccountId, equals('1120'));
      expect(tx.amount, equals(iqd(200000)));
      expect(tx.paymentMethod, equals(OwnerWithdrawalPaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });
  });

  // ---------------------------------------------------------------------------
  // ManufacturingJobTransaction
  // ---------------------------------------------------------------------------
  group('ManufacturingJobTransaction Tests', () {
    test('23. sourceType returns manufacturing', () {
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

      expect(tx.sourceType, equals('manufacturing'));
    });

    test('24. Fields are accessible correctly', () {
      final tx = ManufacturingJobTransaction(
        transactionId: 'mj_2',
        context: ctx,
        idempotencyKey: 'idem_mj_2',
        dateMs: 1700000000000,
        currencyCode: 'IQD',
        description: 'عمل داخلي',
        workshopId: 'ws_2',
        workType: 'تركيب',
        scenario: ManufacturingScenario.internalCost,
        accountingTreatment: ManufacturingAccountingTreatment.materials,
        targetAccountId: '5100',
        cashAccountAccountId: '1120',
        totalCost: Money.fromMinor(180000, 'IQD'),
        customerId: 'cust_1',
        paymentMethod: ManufacturingPaymentMethod.bank,
      );

      expect(tx.transactionId, equals('mj_2'));
      expect(tx.workshopId, equals('ws_2'));
      expect(tx.workType, equals('تركيب'));
      expect(tx.scenario, equals(ManufacturingScenario.internalCost));
      expect(tx.accountingTreatment, equals(ManufacturingAccountingTreatment.materials));
      expect(tx.targetAccountId, equals('5100'));
      expect(tx.cashAccountAccountId, equals('1120'));
      expect(tx.totalCost, equals(iqd(180000)));
      expect(tx.customerId, equals('cust_1'));
      expect(tx.paymentMethod, equals(ManufacturingPaymentMethod.bank));
      expect(tx.companyId, equals('comp_1'));
    });

    test('25. Identity equality holds for same instance', () {
      final tx = ManufacturingJobTransaction(
        transactionId: 'mj_3',
        context: ctx,
        idempotencyKey: 'idem_mj_3',
        dateMs: ctx.timestampMs,
        currencyCode: 'IQD',
        description: 'عمل',
        workshopId: 'ws_1',
        workType: 'تشطيب',
        scenario: ManufacturingScenario.external,
        accountingTreatment: ManufacturingAccountingTreatment.directLabor,
        targetAccountId: '5200',
        cashAccountAccountId: '1110',
        totalCost: Money.fromMinor(100000, 'IQD'),
        paymentMethod: ManufacturingPaymentMethod.cash,
      );

      expect(tx == tx, isTrue);
      expect(tx.hashCode, equals(tx.hashCode));
    });
  });
}

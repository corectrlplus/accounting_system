import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/reversal_engine.dart';
import '../models/accounting_result.dart';
import '../models/transaction_context.dart';
import '../models/transactions/sale_transaction.dart';
import '../models/transactions/purchase_transaction.dart';
import '../models/transactions/customer_payment_transaction.dart';
import '../models/transactions/supplier_payment_transaction.dart';
import '../models/transactions/expense_transaction.dart';
import '../models/transactions/worker_advance_transaction.dart';
import '../models/transactions/worker_salary_transaction.dart';
import '../models/transactions/owner_withdrawal_transaction.dart';
import '../models/transactions/manufacturing_job_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'balance_service.dart';
import 'trial_balance_service.dart';
import 'account_statement_service.dart';
import 'sale_transaction_service.dart';
import 'purchase_transaction_service.dart';
import 'customer_payment_service.dart';
import 'supplier_payment_service.dart';
import 'expense_transaction_service.dart';
import 'worker_advance_service.dart';
import 'worker_salary_service.dart';
import 'owner_withdrawal_service.dart';
import 'manufacturing_job_service.dart';

@immutable
class AccountingFacade {
  final AppDatabase db;
  final String companyId;
  final JournalEntryRepository _journalRepo;

  final BalanceService balanceService;
  final TrialBalanceService trialBalanceService;
  final AccountStatementService accountStatementService;
  final ReversalEngine reversalEngine;

  final SaleTransactionService saleService;
  final PurchaseTransactionService purchaseService;
  final CustomerPaymentService customerPaymentService;
  final SupplierPaymentService supplierPaymentService;
  final ExpenseTransactionService expenseService;
  final WorkerAdvanceService workerAdvanceService;
  final WorkerSalaryService workerSalaryService;
  final OwnerWithdrawalService ownerWithdrawalService;
  final ManufacturingJobService manufacturingJobService;

  const AccountingFacade._({
    required this.db,
    required this.companyId,
    required JournalEntryRepository journalRepo,
    required this.balanceService,
    required this.trialBalanceService,
    required this.accountStatementService,
    required this.reversalEngine,
    required this.saleService,
    required this.purchaseService,
    required this.customerPaymentService,
    required this.supplierPaymentService,
    required this.expenseService,
    required this.workerAdvanceService,
    required this.workerSalaryService,
    required this.ownerWithdrawalService,
    required this.manufacturingJobService,
  }) : _journalRepo = journalRepo;

  factory AccountingFacade({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
    required String companyId,
  }) {
    final cashAccountId = 'acc_1110_$companyId';
    final bankAccountId = 'acc_1120_$companyId';
    final salesAccountId = 'acc_4100_$companyId';
    final directLaborAccountId = 'acc_5200_$companyId';

    return AccountingFacade._(
      db: db,
      companyId: companyId,
      journalRepo: journalRepo,
      balanceService: BalanceService(db),
      trialBalanceService: TrialBalanceService(db),
      accountStatementService: AccountStatementService(db),
      reversalEngine: ReversalEngine(db: db),
      saleService: SaleTransactionService(
        db: db,
        journalRepo: journalRepo,
        cashAccountId: cashAccountId,
        salesAccountId: salesAccountId,
      ),
      purchaseService: PurchaseTransactionService(
        db: db,
        journalRepo: journalRepo,
        cashAccountId: cashAccountId,
      ),
      customerPaymentService: CustomerPaymentService(
        db: db,
        journalRepo: journalRepo,
        cashAccountId: cashAccountId,
        bankAccountId: bankAccountId,
      ),
      supplierPaymentService: SupplierPaymentService(
        db: db,
        journalRepo: journalRepo,
        cashAccountId: cashAccountId,
        bankAccountId: bankAccountId,
      ),
      expenseService: ExpenseTransactionService(
        db: db,
        journalRepo: journalRepo,
      ),
      workerAdvanceService: WorkerAdvanceService(
        db: db,
        journalRepo: journalRepo,
      ),
      workerSalaryService: WorkerSalaryService(
        db: db,
        journalRepo: journalRepo,
        directLaborAccountId: directLaborAccountId,
      ),
      ownerWithdrawalService: OwnerWithdrawalService(
        db: db,
        journalRepo: journalRepo,
      ),
      manufacturingJobService: ManufacturingJobService(
        db: db,
        journalRepo: journalRepo,
      ),
    );
  }

  Future<AccountingResult<SaleData>> executeSale(SaleTransaction tx) =>
      saleService.execute(tx);

  Future<AccountingResult<PurchaseData>> executePurchase(PurchaseTransaction tx) =>
      purchaseService.execute(tx);

  Future<AccountingResult<PaymentData>> executeCustomerPayment(CustomerPaymentTransaction tx) =>
      customerPaymentService.execute(tx);

  Future<AccountingResult<PaymentData>> executeSupplierPayment(SupplierPaymentTransaction tx) =>
      supplierPaymentService.execute(tx);

  Future<AccountingResult<ExpenseData>> executeExpense(ExpenseTransaction tx) =>
      expenseService.execute(tx);

  Future<AccountingResult<WorkerAdvanceData>> executeWorkerAdvance(WorkerAdvanceTransaction tx) =>
      workerAdvanceService.execute(tx);

  Future<AccountingResult<WorkerSalaryData>> executeWorkerSalary(WorkerSalaryTransaction tx) =>
      workerSalaryService.execute(tx);

  Future<AccountingResult<OwnerWithdrawalData>> executeOwnerWithdrawal(OwnerWithdrawalTransaction tx) =>
      ownerWithdrawalService.execute(tx);

  Future<AccountingResult<ManufacturingJobData>> executeManufacturingJob(ManufacturingJobTransaction tx) =>
      manufacturingJobService.execute(tx);

  Future<int> getAccountBalance(String accountId) =>
      balanceService.getAccountBalance(accountId);

  Future<int> getCustomerBalance(String customerId) =>
      balanceService.getCustomerBalance(customerId, companyId);

  Future<int> getSupplierBalance(String supplierId) =>
      balanceService.getSupplierBalance(supplierId, companyId);

  Future<int> getWorkerAdvanceBalance(String workerId) =>
      balanceService.getWorkerAdvanceBalance(workerId, companyId);

  Future<int> getCashBalance() =>
      balanceService.getCashBalance(companyId);

  Future<List<TrialBalanceLine>> getTrialBalance() =>
      trialBalanceService.generate(companyId);

  Future<List<AccountStatementLine>> getAccountStatement(
    String accountId, {
    int? fromDateMs,
    int? toDateMs,
  }) =>
      accountStatementService.getAccountStatement(
        accountId,
        fromDateMs: fromDateMs,
        toDateMs: toDateMs,
      );

  Future<AccountingResult<JournalEntryData>> reverseEntry({
    required String entryId,
    required String reason,
    required String userId,
    required String deviceId,
  }) {
    final context = TransactionContext(
      companyId: companyId,
      userId: userId,
      deviceId: deviceId,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    return reversalEngine.reverse(
      originalEntryId: entryId,
      context: context,
      reversalDescription: reason,
    );
  }

  Future<void> seedCompanyDefaults(String deviceId) =>
      db.seedCompanyDefaults(companyId, deviceId);
}

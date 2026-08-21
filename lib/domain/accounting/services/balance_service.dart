import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Financial balance derivation service providing real-time balance queries
/// for accounts, customers, suppliers, workers, and cash positions.
///
/// All balances are derived on-the-fly from immutable journal entry lines via
/// [AppDatabase.getDerivedAccountBalance], ensuring consistency with the
/// double-entry ledger without denormalized balance caching.
///
/// Balance calculation follows standard accounting conventions:
/// - **Debit-normal** (Assets, COGS, Expenses): balance = SUM(debit) - SUM(credit)
/// - **Credit-normal** (Liabilities, Equity, Revenue): balance = SUM(credit) - SUM(debit)
@immutable
class BalanceService {
  final AppDatabase db;

  const BalanceService(this.db);

  /// Get the derived balance for a specific account.
  ///
  /// Returns the net balance in minor units (x1000). Positive values represent
  /// the normal balance direction for the account type.
  ///
  /// Returns 0 if the account does not exist.
  Future<int> getAccountBalance(String accountId) {
    return db.getDerivedAccountBalance(accountId);
  }

  /// Get the outstanding balance for a customer (Accounts Receivable sub-account).
  ///
  /// Looks up the customer's linked AR account and derives its current balance
  /// from journal entry lines. A positive balance indicates the customer owes money.
  ///
  /// Returns 0 if the customer does not exist.
  Future<int> getCustomerBalance(String customerId, String companyId) async {
    final customer = await (db.select(db.customers)
          ..where((c) => c.id.equals(customerId) & c.companyId.equals(companyId)))
        .getSingleOrNull();

    if (customer == null) return 0;
    return db.getDerivedAccountBalance(customer.accountId);
  }

  /// Get the outstanding balance for a supplier (Accounts Payable sub-account).
  ///
  /// Looks up the supplier's linked AP account and derives its current balance
  /// from journal entry lines. A positive balance indicates the company owes money.
  ///
  /// Returns 0 if the supplier does not exist.
  Future<int> getSupplierBalance(String supplierId, String companyId) async {
    final supplier = await (db.select(db.suppliers)
          ..where((s) =>
              s.id.equals(supplierId) & s.companyId.equals(companyId)))
        .getSingleOrNull();

    if (supplier == null) return 0;
    return db.getDerivedAccountBalance(supplier.accountId);
  }

  /// Get the outstanding advance balance for a worker.
  ///
  /// Looks up the worker's linked advance sub-account and derives its current
  /// balance from journal entry lines. A positive balance indicates the worker
  /// has unspent advance funds.
  ///
  /// Returns 0 if the worker does not exist.
  Future<int> getWorkerAdvanceBalance(String workerId, String companyId) async {
    final worker = await (db.select(db.workers)
          ..where((w) =>
              w.id.equals(workerId) & w.companyId.equals(companyId)))
        .getSingleOrNull();

    if (worker == null) return 0;
    return db.getDerivedAccountBalance(worker.accountId);
  }

  /// Get the total cash position across all cash and bank accounts for a company.
  ///
  /// Sums the derived balances of all accounts with codes '1110' (Cash on Hand)
  /// and '1120' (Bank Account) that belong to the specified company.
  ///
  /// Returns 0 if no cash/bank accounts exist.
  Future<int> getCashBalance(String companyId) async {
    final cashAccounts = await (db.select(db.accounts)
          ..where((a) =>
              a.companyId.equals(companyId) &
              a.isActive.equals(true) &
              (a.code.equals('1110') | a.code.equals('1120'))))
        .get();

    int total = 0;
    for (final account in cashAccounts) {
      total += await db.getDerivedAccountBalance(account.id);
    }
    return total;
  }
}

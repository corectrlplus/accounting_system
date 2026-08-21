import 'package:drift/drift.dart';

/// Table 11: sales
@DataClassName('SaleData')
class Sales extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get customerId => text().nullable()();
  IntColumn get saleNumber => integer()();
  IntColumn get date => integer()(); // Unix ms timestamp
  IntColumn get totalAmount => integer()(); // Minor units (x1000)
  IntColumn get cashReceived => integer().withDefault(const Constant(0))();
  IntColumn get creditAmount => integer().withDefault(const Constant(0))();
  TextColumn get paymentType => text()(); // cash, credit, mixed
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 12: sale_items
@DataClassName('SaleItemData')
class SaleItems extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get saleId => text()();
  TextColumn get description => text()();
  IntColumn get quantity => integer()(); // Minor units (x1000 for fractional)
  IntColumn get unitPrice => integer()(); // Minor units (x1000)
  IntColumn get totalPrice => integer()(); // Minor units (x1000)
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 13: purchases
@DataClassName('PurchaseData')
class Purchases extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get supplierId => text().nullable()();
  IntColumn get purchaseNumber => integer()();
  IntColumn get date => integer()();
  IntColumn get totalAmount => integer()();
  IntColumn get cashPaid => integer().withDefault(const Constant(0))();
  IntColumn get creditAmount => integer().withDefault(const Constant(0))();
  TextColumn get paymentType => text()(); // cash, credit, mixed
  TextColumn get accountingNature => text()(); // inventory, materials, operating_expense, service, other
  TextColumn get targetAccountId => text()();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 14: purchase_items
@DataClassName('PurchaseItemData')
class PurchaseItems extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get purchaseId => text()();
  TextColumn get description => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitPrice => integer()();
  IntColumn get totalPrice => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 15: payments
@DataClassName('PaymentData')
class Payments extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  IntColumn get paymentNumber => integer()();
  IntColumn get date => integer()();
  IntColumn get amount => integer()();
  TextColumn get paymentMethod => text()(); // cash, bank, other
  TextColumn get direction => text()(); // incoming, outgoing
  TextColumn get customerId => text().nullable()();
  TextColumn get supplierId => text().nullable()();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 16: payment_allocations
/// Relational Design: Explicit Dual Foreign Keys (`saleId` & `purchaseId`)
@DataClassName('PaymentAllocationData')
class PaymentAllocations extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get paymentId => text()();
  TextColumn get saleId => text().nullable()();
  TextColumn get purchaseId => text().nullable()();
  IntColumn get allocatedAmount => integer()(); // Minor units (x1000)

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 17: expenses
@DataClassName('ExpenseData')
class Expenses extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  IntColumn get expenseNumber => integer()();
  IntColumn get date => integer()();
  IntColumn get amount => integer()();
  TextColumn get expenseCategoryId => text()();
  TextColumn get paymentMethod => text()(); // cash, bank, other
  TextColumn get description => text().nullable()();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 19: worker_advances
@DataClassName('WorkerAdvanceData')
class WorkerAdvances extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get workerId => text()();
  IntColumn get date => integer()();
  IntColumn get amount => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 20: worker_salaries
@DataClassName('WorkerSalaryData')
class WorkerSalaries extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get workerId => text()();
  IntColumn get date => integer()();
  IntColumn get grossSalary => integer()();
  IntColumn get advanceDeduction => integer().withDefault(const Constant(0))();
  IntColumn get netPayment => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 21: owner_withdrawals
@DataClassName('OwnerWithdrawalData')
class OwnerWithdrawals extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  IntColumn get date => integer()();
  IntColumn get amount => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get description => text().nullable()();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 22: manufacturing_jobs
@DataClassName('ManufacturingJobData')
class ManufacturingJobs extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  IntColumn get jobNumber => integer()();
  TextColumn get workshopId => text()();
  TextColumn get workType => text()();
  TextColumn get scenario => text()(); // external, owner_internal, internal_cost
  TextColumn get accountingTreatment => text()(); // revenue, cost_of_manufacturing, direct_labor, materials, overhead
  IntColumn get totalCost => integer()();
  IntColumn get date => integer()();
  TextColumn get customerId => text().nullable()();
  TextColumn get responsiblePerson => text().nullable()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get journalEntryId => text()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get idempotencyKey => text().unique()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Base class for all database & integrity exceptions.
class AccountingDatabaseException implements Exception {
  final String message;
  final String? code;

  AccountingDatabaseException(this.message, [this.code]);

  @override
  String toString() => 'AccountingDatabaseException[$code]: $message';
}

/// Thrown when a journal entry's total debits do not equal total credits.
class LedgerImbalanceException extends AccountingDatabaseException {
  final int totalDebits;
  final int totalCredits;

  LedgerImbalanceException(this.totalDebits, this.totalCredits)
      : super(
          'Ledger imbalance detected: Total Debits ($totalDebits) != Total Credits ($totalCredits)',
          'LEDGER_UNBALANCED',
        );
}

/// Thrown when concurrent allocations attempt to exceed invoice total or payment total.
class AllocationConcurrencyException extends AccountingDatabaseException {
  final String targetId;
  final int currentAllocated;
  final int attemptedAllocated;
  final int maxAllowed;

  AllocationConcurrencyException({
    required this.targetId,
    required this.currentAllocated,
    required this.attemptedAllocated,
    required this.maxAllowed,
  }) : super(
          'Allocation limit exceeded for $targetId: Attempted total (${currentAllocated + attemptedAllocated}) > Max allowed ($maxAllowed)',
          'ALLOCATION_CONCURRENCY_EXCEEDED',
        );
}

/// Thrown when a payment direction misaligns with allocation target (e.g. incoming payment allocated to purchase).
class PaymentDirectionMismatchException extends AccountingDatabaseException {
  final String direction;
  final String targetType;

  PaymentDirectionMismatchException(this.direction, this.targetType)
      : super(
          'Payment direction mismatch: Cannot allocate $direction payment to $targetType document',
          'PAYMENT_DIRECTION_MISMATCH',
        );
}

/// Thrown when salary advance deduction exceeds worker's outstanding advance balance.
class WorkerAdvanceExceededException extends AccountingDatabaseException {
  final String workerId;
  final int attemptedDeduction;
  final int currentBalance;

  WorkerAdvanceExceededException({
    required this.workerId,
    required this.attemptedDeduction,
    required this.currentBalance,
  }) : super(
          'Worker advance deduction ($attemptedDeduction) exceeds current advance balance ($currentBalance) for worker $workerId',
          'WORKER_ADVANCE_EXCEEDED',
        );
}

/// Thrown when attempting to update or delete an immutable posted journal entry.
class ImmutableLedgerException extends AccountingDatabaseException {
  final String entryId;

  ImmutableLedgerException(this.entryId)
      : super(
          'Cannot modify or delete posted journal entry $entryId. Posted entries are append-only. Use reversal.',
          'IMMUTABLE_LEDGER_VIOLATION',
        );
}

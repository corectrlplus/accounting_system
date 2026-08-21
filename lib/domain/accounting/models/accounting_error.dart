import 'package:meta/meta.dart';
import '../../../core/money/money.dart';

/// Strongly-typed domain error hierarchy for the Accounting Engine.
@immutable
abstract class AccountingError {
  final String message;
  final String code;

  const AccountingError({required this.message, required this.code});

  @override
  String toString() => 'AccountingError[$code]: $message';
}

/// Generic transaction or business validation failure.
class ValidationError extends AccountingError {
  final String fieldName;

  const ValidationError({required String message, required this.fieldName})
      : super(message: message, code: 'VALIDATION_ERROR');
}

/// Journal entry balance invariant failure ($\sum debit \ne \sum credit$).
class ImbalanceError extends AccountingError {
  final Money totalDebit;
  final Money totalCredit;

  ImbalanceError({required this.totalDebit, required this.totalCredit})
      : super(
          message:
              'Journal entry imbalance: Total Debit (${totalDebit.amountMinor}) != Total Credit (${totalCredit.amountMinor})',
          code: 'LEDGER_IMBALANCE',
        );
}

/// Duplicate idempotency key transaction submission.
class IdempotencyError extends AccountingError {
  final String idempotencyKey;

  IdempotencyError({required this.idempotencyKey})
      : super(
          message: 'Transaction with idempotency key $idempotencyKey already exists',
          code: 'IDEMPOTENCY_CONFLICT',
        );
}

/// Concurrent allocation limit violation (TOCTOU lock protection).
class ConcurrencyError extends AccountingError {
  final String targetId;
  final Money currentAllocated;
  final Money attemptedAllocated;
  final Money maxAllowed;

  ConcurrencyError({
    required this.targetId,
    required this.currentAllocated,
    required this.attemptedAllocated,
    required this.maxAllowed,
  }) : super(
          message:
              'Allocation concurrency failure on $targetId: current (${currentAllocated.amountMinor}) + attempted (${attemptedAllocated.amountMinor}) > max allowed (${maxAllowed.amountMinor})',
          code: 'ALLOCATION_CONCURRENCY_VIOLATION',
        );
}

/// Payment allocation direction mismatch (incoming $\rightarrow$ purchase or outgoing $\rightarrow$ sale).
class DirectionMismatchError extends AccountingError {
  final String paymentDirection;
  final String targetType;

  DirectionMismatchError({required this.paymentDirection, required this.targetType})
      : super(
          message:
              'Payment direction mismatch: $paymentDirection payment cannot be allocated to $targetType',
          code: 'PAYMENT_DIRECTION_MISMATCH',
        );
}

/// Worker advance deduction exceeds derived outstanding advance balance.
class InsufficientAdvanceBalanceError extends AccountingError {
  final String workerId;
  final Money availableAdvance;
  final Money attemptedDeduction;

  InsufficientAdvanceBalanceError({
    required this.workerId,
    required this.availableAdvance,
    required this.attemptedDeduction,
  }) : super(
          message:
              'Insufficient worker advance balance for $workerId: attempted deduction (${attemptedDeduction.amountMinor}) exceeds derived advance balance (${availableAdvance.amountMinor})',
          code: 'INSUFFICIENT_ADVANCE_BALANCE',
        );
}

/// Attempt to edit or delete posted ledger entry or line.
class ImmutableLedgerError extends AccountingError {
  final String entityId;

  ImmutableLedgerError({required this.entityId})
      : super(
          message: 'Immutable ledger violation: Posted entry $entityId cannot be mutated or deleted',
          code: 'IMMUTABLE_LEDGER_VIOLATION',
        );
}

/// Multi-tenant company isolation violation.
class CompanyMismatchError extends AccountingError {
  final String expectedCompanyId;
  final String actualCompanyId;

  CompanyMismatchError({required this.expectedCompanyId, required this.actualCompanyId})
      : super(
          message:
              'Company isolation mismatch: Expected $expectedCompanyId but received $actualCompanyId',
          code: 'COMPANY_MISMATCH',
        );
}

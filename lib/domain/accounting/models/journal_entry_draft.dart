import 'package:meta/meta.dart';
import '../../../core/money/money.dart';
import 'accounting_error.dart';
import 'accounting_result.dart';

/// Single line draft in a double-entry journal entry.
///
/// Enforces:
/// 1. `debitAmount >= 0` and `creditAmount >= 0`.
/// 2. Exactly one side > 0 (No zero lines, no double-populated lines).
/// 3. Standard Money Value Object usage.
@immutable
class JournalLineDraft {
  final String accountId;
  final Money debitAmount;
  final Money creditAmount;
  final String? description;

  JournalLineDraft({
    required this.accountId,
    required this.debitAmount,
    required this.creditAmount,
    this.description,
  }) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('Account ID cannot be empty');
    }
    if (debitAmount.currency != creditAmount.currency) {
      throw ArgumentError('Debit and credit currency mismatch: ${debitAmount.currency} vs ${creditAmount.currency}');
    }
    if (debitAmount.isNegative || creditAmount.isNegative) {
      throw ArgumentError('Debit and credit amounts cannot be negative');
    }
    if (debitAmount.isZero && creditAmount.isZero) {
      throw ArgumentError('Journal line must have either debit or credit greater than zero');
    }
    if (debitAmount.isPositive && creditAmount.isPositive) {
      throw ArgumentError('Journal line cannot have both debit and credit greater than zero');
    }
  }

  /// Helper factory creating a Debit line.
  factory JournalLineDraft.debit({
    required String accountId,
    required Money amount,
    String? description,
  }) {
    return JournalLineDraft(
      accountId: accountId,
      debitAmount: amount,
      creditAmount: Money.zero(amount.currency),
      description: description,
    );
  }

  /// Helper factory creating a Credit line.
  factory JournalLineDraft.credit({
    required String accountId,
    required Money amount,
    String? description,
  }) {
    return JournalLineDraft(
      accountId: accountId,
      creditAmount: amount,
      debitAmount: Money.zero(amount.currency),
      description: description,
    );
  }

  String get currency => debitAmount.currency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalLineDraft &&
          runtimeType == other.runtimeType &&
          accountId == other.accountId &&
          debitAmount == other.debitAmount &&
          creditAmount == other.creditAmount &&
          description == other.description;

  @override
  int get hashCode =>
      accountId.hashCode ^ debitAmount.hashCode ^ creditAmount.hashCode ^ description.hashCode;
}

/// Draft representation of an unpersisted double-entry journal entry header + lines.
@immutable
class JournalEntryDraft {
  final String id;
  final String companyId;
  final int? entryNumber;
  final int dateMs;
  final String description;
  final String? reference;
  final String sourceType;
  final String sourceId;
  final bool isReversal;
  final String? reversedEntryId;
  final String status;
  final String currencyCode;
  final String idempotencyKey;
  final String createdBy;
  final List<JournalLineDraft> lines;

  JournalEntryDraft({
    required this.id,
    required this.companyId,
    this.entryNumber,
    required this.dateMs,
    required this.description,
    this.reference,
    required this.sourceType,
    required this.sourceId,
    this.isReversal = false,
    this.reversedEntryId,
    this.status = 'posted',
    required this.currencyCode,
    required this.idempotencyKey,
    required this.createdBy,
    required List<JournalLineDraft> lines,
  }) : lines = List.unmodifiable(lines) {
    if (id.trim().isEmpty) throw ArgumentError('Journal entry ID cannot be empty');
    if (companyId.trim().isEmpty) throw ArgumentError('Company ID cannot be empty');
    if (description.trim().isEmpty) throw ArgumentError('Description cannot be empty');
    if (sourceType.trim().isEmpty) throw ArgumentError('Source type cannot be empty');
    if (sourceId.trim().isEmpty) throw ArgumentError('Source ID cannot be empty');
    if (idempotencyKey.trim().isEmpty) throw ArgumentError('Idempotency key cannot be empty');
    if (createdBy.trim().isEmpty) throw ArgumentError('Created by user ID cannot be empty');
    if (lines.isEmpty) throw ArgumentError('Journal entry must contain at least two lines');

    for (final line in lines) {
      if (line.currency != currencyCode) {
        throw ArgumentError('Line currency ${line.currency} does not match entry currency $currencyCode');
      }
    }
  }

  /// Calculate total debit amount across all lines.
  Money get totalDebit {
    return lines.fold<Money>(
      Money.zero(currencyCode),
      (sum, line) => sum + line.debitAmount,
    );
  }

  /// Calculate total credit amount across all lines.
  Money get totalCredit {
    return lines.fold<Money>(
      Money.zero(currencyCode),
      (sum, line) => sum + line.creditAmount,
    );
  }

  /// True if total debits equal total credits.
  bool get isBalanced => totalDebit == totalCredit;

  /// Validate entry balance and return deterministic AccountingResult.
  AccountingResult<void> validateBalance() {
    if (!isBalanced) {
      return AccountingResult.failure(
        ImbalanceError(totalDebit: totalDebit, totalCredit: totalCredit),
      );
    }
    return AccountingResult.success(null);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryDraft &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          companyId == other.companyId &&
          entryNumber == other.entryNumber &&
          dateMs == other.dateMs &&
          description == other.description &&
          reference == other.reference &&
          sourceType == other.sourceType &&
          sourceId == other.sourceId &&
          isReversal == other.isReversal &&
          reversedEntryId == other.reversedEntryId &&
          status == other.status &&
          currencyCode == other.currencyCode &&
          idempotencyKey == other.idempotencyKey &&
          createdBy == other.createdBy;

  @override
  int get hashCode =>
      id.hashCode ^
      companyId.hashCode ^
      dateMs.hashCode ^
      sourceType.hashCode ^
      sourceId.hashCode ^
      idempotencyKey.hashCode;
}

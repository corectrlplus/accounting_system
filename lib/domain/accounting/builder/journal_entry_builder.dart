import '../../../core/money/money.dart';
import '../../../core/sync/idempotency_generator.dart';
import '../models/transaction_context.dart';
import '../models/journal_entry_draft.dart';
import '../models/accounting_result.dart';
import '../models/accounting_error.dart';

/// Centralized, reusable builder for creating balanced, validated [JournalEntryDraft] instances.
class JournalEntryBuilder {
  String? _id;
  TransactionContext? _context;
  String? _sourceType;
  String? _sourceId;
  String? _description;
  String? _reference;
  String _currencyCode = 'IQD';
  bool _isReversal = false;
  String? _reversedEntryId;
  String? _customIdempotencyKey;
  final List<JournalLineDraft> _lines = [];

  JournalEntryBuilder();

  /// Set execution transaction context.
  JournalEntryBuilder setContext(TransactionContext context) {
    _context = context;
    return this;
  }

  /// Set optional custom entry ID (defaults to new UUID v4).
  JournalEntryBuilder setId(String id) {
    _id = id;
    return this;
  }

  /// Set source transaction type and source entity ID.
  JournalEntryBuilder setSource({required String sourceType, required String sourceId}) {
    _sourceType = sourceType;
    _sourceId = sourceId;
    return this;
  }

  /// Set entry description.
  JournalEntryBuilder setDescription(String description) {
    _description = description;
    return this;
  }

  /// Set entry reference number/document.
  JournalEntryBuilder setReference(String? reference) {
    _reference = reference;
    return this;
  }

  /// Set entry currency code (defaults to 'IQD').
  JournalEntryBuilder setCurrency(String currencyCode) {
    _currencyCode = currencyCode;
    return this;
  }

  /// Mark as reversal entry and link original entry ID.
  JournalEntryBuilder setReversal({required String reversedEntryId}) {
    _isReversal = true;
    _reversedEntryId = reversedEntryId;
    return this;
  }

  /// Set explicit idempotency key (defaults to deterministic key from context + source).
  JournalEntryBuilder setIdempotencyKey(String key) {
    _customIdempotencyKey = key;
    return this;
  }

  /// Add a Debit line to the entry draft.
  JournalEntryBuilder addDebit({
    required String accountId,
    required Money amount,
    String? description,
  }) {
    _lines.add(
      JournalLineDraft.debit(
        accountId: accountId,
        amount: amount,
        description: description,
      ),
    );
    return this;
  }

  /// Add a Credit line to the entry draft.
  JournalEntryBuilder addCredit({
    required String accountId,
    required Money amount,
    String? description,
  }) {
    _lines.add(
      JournalLineDraft.credit(
        accountId: accountId,
        amount: amount,
        description: description,
      ),
    );
    return this;
  }

  /// Add an explicit [JournalLineDraft] line.
  JournalEntryBuilder addLine(JournalLineDraft line) {
    _lines.add(line);
    return this;
  }

  /// Calculate running total debits of added lines.
  Money get currentTotalDebit {
    return _lines.fold<Money>(
      Money.zero(_currencyCode),
      (sum, l) => sum + l.debitAmount,
    );
  }

  /// Calculate running total credits of added lines.
  Money get currentTotalCredit {
    return _lines.fold<Money>(
      Money.zero(_currencyCode),
      (sum, l) => sum + l.creditAmount,
    );
  }

  /// Build and validate the [JournalEntryDraft].
  AccountingResult<JournalEntryDraft> build() {
    if (_context == null) {
      return AccountingResult.failure(
        const ValidationError(message: 'TransactionContext is required', fieldName: 'context'),
      );
    }
    if (_sourceType == null || _sourceType!.trim().isEmpty) {
      return AccountingResult.failure(
        const ValidationError(message: 'Source type is required', fieldName: 'sourceType'),
      );
    }
    if (_sourceId == null || _sourceId!.trim().isEmpty) {
      return AccountingResult.failure(
        const ValidationError(message: 'Source ID is required', fieldName: 'sourceId'),
      );
    }
    if (_description == null || _description!.trim().isEmpty) {
      return AccountingResult.failure(
        const ValidationError(message: 'Description is required', fieldName: 'description'),
      );
    }

    if (_lines.length < 2) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Journal entry must contain at least two lines (has ${_lines.length})',
          fieldName: 'lines',
        ),
      );
    }

    // Currency verification across all lines
    for (final line in _lines) {
      if (line.currency != _currencyCode) {
        return AccountingResult.failure(
          ValidationError(
            message: 'Line currency ${line.currency} does not match entry currency $_currencyCode',
            fieldName: 'currencyCode',
          ),
        );
      }
    }

    // Idempotency Key Generation (Deterministic)
    final idempotencyKey = _customIdempotencyKey ??
        IdempotencyGenerator.generateKey(
          companyId: _context!.companyId,
          sourceType: _sourceType!,
          sourceId: _sourceId!,
          deviceId: _context!.deviceId,
        );

    final entryId = _id ?? IdempotencyGenerator.generateUuid();

    final draft = JournalEntryDraft(
      id: entryId,
      companyId: _context!.companyId,
      dateMs: _context!.timestampMs,
      description: _description!,
      reference: _reference,
      sourceType: _sourceType!,
      sourceId: _sourceId!,
      isReversal: _isReversal,
      reversedEntryId: _reversedEntryId,
      status: 'posted',
      currencyCode: _currencyCode,
      idempotencyKey: idempotencyKey,
      createdBy: _context!.userId,
      lines: _lines,
    );

    // Balance verification ($\sum debit == \sum credit$)
    final balanceResult = draft.validateBalance();
    if (balanceResult.isFailure) {
      return AccountingResult.failure(balanceResult.error);
    }

    return AccountingResult.success(draft);
  }
}

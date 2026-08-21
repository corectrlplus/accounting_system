import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/supplier_payment_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for outgoing supplier payments.
///
/// Creates a balanced journal entry that debits Accounts Payable (the
/// supplier's sub-account) and credits the cash/bank account.
///
/// The cash/bank account is resolved from [SupplierPaymentMethod]:
/// - [SupplierPaymentMethod.cash] → [cashAccountId]
/// - [SupplierPaymentMethod.bank] → [bankAccountId]
/// - [SupplierPaymentMethod.other] → [cashAccountId] (fallback)
@immutable
class SupplierPaymentEngine extends TransactionEngine<SupplierPaymentTransaction> {
  final String cashAccountId;
  final String bankAccountId;

  const SupplierPaymentEngine({
    required JournalEntryRepository repository,
    required this.cashAccountId,
    required this.bankAccountId,
  }) : super(repository);

  String _resolveCashAccount(SupplierPaymentMethod method) {
    switch (method) {
      case SupplierPaymentMethod.cash:
        return cashAccountId;
      case SupplierPaymentMethod.bank:
        return bankAccountId;
      case SupplierPaymentMethod.other:
        return cashAccountId;
    }
  }

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(SupplierPaymentTransaction tx) {
    final paidAccountId = _resolveCashAccount(tx.paymentMethod);

    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.supplierAccountId, amount: tx.amount)
        .addCredit(accountId: paidAccountId, amount: tx.amount)
        .build();
  }
}

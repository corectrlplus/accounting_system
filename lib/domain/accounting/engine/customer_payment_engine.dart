import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/customer_payment_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for incoming customer payments.
///
/// Creates a balanced journal entry that debits the cash/bank account and
/// credits Accounts Receivable (the customer's sub-account).
///
/// The cash/bank account is resolved from [CustomerPaymentMethod]:
/// - [CustomerPaymentMethod.cash] → [cashAccountId]
/// - [CustomerPaymentMethod.bank] → [bankAccountId]
/// - [CustomerPaymentMethod.other] → [cashAccountId] (fallback)
@immutable
class CustomerPaymentEngine extends TransactionEngine<CustomerPaymentTransaction> {
  final String cashAccountId;
  final String bankAccountId;

  const CustomerPaymentEngine({
    required JournalEntryRepository repository,
    required this.cashAccountId,
    required this.bankAccountId,
  }) : super(repository);

  String _resolveCashAccount(CustomerPaymentMethod method) {
    switch (method) {
      case CustomerPaymentMethod.cash:
        return cashAccountId;
      case CustomerPaymentMethod.bank:
        return bankAccountId;
      case CustomerPaymentMethod.other:
        return cashAccountId;
    }
  }

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(CustomerPaymentTransaction tx) {
    final receivedAccountId = _resolveCashAccount(tx.paymentMethod);

    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: receivedAccountId, amount: tx.amount)
        .addCredit(accountId: tx.customerAccountId, amount: tx.amount)
        .build();
  }
}

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

@immutable
class GeneralLedgerEntry {
  final String entryId;
  final int entryNumber;
  final int dateMs;
  final String description;
  final String sourceType;
  final bool isReversal;
  final String accountCode;
  final String accountNameAr;
  final int debitAmount;
  final int creditAmount;

  const GeneralLedgerEntry({
    required this.entryId,
    required this.entryNumber,
    required this.dateMs,
    required this.description,
    required this.sourceType,
    required this.isReversal,
    required this.accountCode,
    required this.accountNameAr,
    required this.debitAmount,
    required this.creditAmount,
  });
}

@immutable
class GeneralLedgerReport {
  final String companyId;
  final int fromDateMs;
  final int toDateMs;
  final List<GeneralLedgerEntry> entries;
  final int totalDebit;
  final int totalCredit;

  const GeneralLedgerReport({
    required this.companyId,
    required this.fromDateMs,
    required this.toDateMs,
    required this.entries,
    required this.totalDebit,
    required this.totalCredit,
  });
}

@immutable
class GeneralLedgerService {
  final AppDatabase db;

  const GeneralLedgerService(this.db);

  Future<GeneralLedgerReport> generate(
    String companyId, {
    int? fromDateMs,
    int? toDateMs,
  }) async {
    final effectiveFrom = fromDateMs ?? 0;
    final effectiveTo = toDateMs ?? DateTime.now().millisecondsSinceEpoch;

    final journalEntries = await (db.select(db.journalEntries)
          ..where((j) =>
              j.companyId.equals(companyId) &
              j.status.equals('posted') &
              j.date.isBiggerOrEqualValue(effectiveFrom) &
              j.date.isSmallerOrEqualValue(effectiveTo))
          ..orderBy([
            (j) => OrderingTerm.asc(j.date),
            (j) => OrderingTerm.asc(j.entryNumber),
          ]))
        .get();

    final entries = <GeneralLedgerEntry>[];
    int totalDebit = 0;
    int totalCredit = 0;

    for (final entry in journalEntries) {
      final lines = await (db.select(db.journalEntryLines)
            ..where((l) =>
                l.journalEntryId.equals(entry.id) &
                l.companyId.equals(companyId)))
          .get();

      for (final line in lines) {
        final account = await (db.select(db.accounts)
              ..where((a) => a.id.equals(line.accountId)))
            .getSingleOrNull();

        final accountCode = account?.code ?? '???';
        final accountNameAr = account?.nameAr ?? '---';

        entries.add(GeneralLedgerEntry(
          entryId: entry.id,
          entryNumber: entry.entryNumber,
          dateMs: entry.date,
          description: entry.description,
          sourceType: entry.sourceType,
          isReversal: entry.isReversal,
          accountCode: accountCode,
          accountNameAr: accountNameAr,
          debitAmount: line.debitAmount,
          creditAmount: line.creditAmount,
        ));

        totalDebit += line.debitAmount;
        totalCredit += line.creditAmount;
      }
    }

    return GeneralLedgerReport(
      companyId: companyId,
      fromDateMs: effectiveFrom,
      toDateMs: effectiveTo,
      entries: entries,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
    );
  }
}

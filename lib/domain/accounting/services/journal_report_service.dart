import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

@immutable
class JournalReportLine {
  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final int debitAmount;
  final int creditAmount;
  final String? description;

  const JournalReportLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.debitAmount,
    required this.creditAmount,
    this.description,
  });
}

@immutable
class JournalReportEntry {
  final String entryId;
  final int entryNumber;
  final int dateMs;
  final String description;
  final String? reference;
  final String sourceType;
  final bool isReversal;
  final String status;
  final List<JournalReportLine> lines;
  final int totalDebit;
  final int totalCredit;

  const JournalReportEntry({
    required this.entryId,
    required this.entryNumber,
    required this.dateMs,
    required this.description,
    this.reference,
    required this.sourceType,
    required this.isReversal,
    required this.status,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
  });
}

@immutable
class JournalReport {
  final String companyId;
  final int? fromDateMs;
  final int? toDateMs;
  final List<JournalReportEntry> entries;
  final int grandTotalDebit;
  final int grandTotalCredit;

  const JournalReport({
    required this.companyId,
    this.fromDateMs,
    this.toDateMs,
    required this.entries,
    required this.grandTotalDebit,
    required this.grandTotalCredit,
  });
}

@immutable
class JournalReportService {
  final AppDatabase db;

  const JournalReportService(this.db);

  Future<JournalReport> generate(
    String companyId, {
    int? fromDateMs,
    int? toDateMs,
  }) async {
    Expression<bool> dateCondition;

    if (fromDateMs != null && toDateMs != null) {
      dateCondition = db.journalEntries.date
          .isBetweenValues(fromDateMs, toDateMs);
    } else if (fromDateMs != null) {
      dateCondition = db.journalEntries.date.isBiggerOrEqualValue(fromDateMs);
    } else if (toDateMs != null) {
      dateCondition = db.journalEntries.date.isSmallerOrEqualValue(toDateMs);
    } else {
      dateCondition = const Constant(true);
    }

    final journalEntries = await (db.select(db.journalEntries)
          ..where((j) => j.companyId.equals(companyId) & dateCondition)
          ..orderBy([(j) => OrderingTerm.asc(j.entryNumber)]))
        .get();

    final reportEntries = <JournalReportEntry>[];
    int grandTotalDebit = 0;
    int grandTotalCredit = 0;

    for (final entry in journalEntries) {
      final lines = await (db.select(db.journalEntryLines)
            ..where((l) =>
                l.journalEntryId.equals(entry.id) &
                l.companyId.equals(companyId)))
          .get();

      final reportLines = <JournalReportLine>[];
      int totalDebit = 0;
      int totalCredit = 0;

      for (final line in lines) {
        final account = await (db.select(db.accounts)
              ..where((a) => a.id.equals(line.accountId)))
            .getSingleOrNull();

        reportLines.add(JournalReportLine(
          accountId: line.accountId,
          accountCode: account?.code ?? '???',
          accountNameAr: account?.nameAr ?? '---',
          debitAmount: line.debitAmount,
          creditAmount: line.creditAmount,
          description: line.description,
        ));

        totalDebit += line.debitAmount;
        totalCredit += line.creditAmount;
      }

      reportEntries.add(JournalReportEntry(
        entryId: entry.id,
        entryNumber: entry.entryNumber,
        dateMs: entry.date,
        description: entry.description,
        reference: entry.reference,
        sourceType: entry.sourceType,
        isReversal: entry.isReversal,
        status: entry.status,
        lines: reportLines,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
      ));

      grandTotalDebit += totalDebit;
      grandTotalCredit += totalCredit;
    }

    return JournalReport(
      companyId: companyId,
      fromDateMs: fromDateMs,
      toDateMs: toDateMs,
      entries: reportEntries,
      grandTotalDebit: grandTotalDebit,
      grandTotalCredit: grandTotalCredit,
    );
  }
}

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Cash flow statement (قائمة التدفقات النقدية) report service.
///
/// Produces a standard cash flow statement categorized into three sections:
/// - **Operating Activities**: Customer payments, supplier payments, expenses,
///   worker wages, worker advances
/// - **Investing Activities**: Equipment purchases, manufacturing costs
/// - **Financing Activities**: Owner withdrawals, owner capital injections
///
/// All monetary values are in minor units (x1000).
///
/// Incoming flows are positive, outgoing flows are negative within each section.
@immutable
class CashFlowReportService {
  final AppDatabase db;

  const CashFlowReportService(this.db);

  /// Generate a cash flow statement for the specified company and date range.
  ///
  /// Parameters:
  /// - [companyId]: The company to generate the report for.
  /// - [fromDateMs]: Start of the reporting period (Unix ms), inclusive.
  /// - [toDateMs]: End of the reporting period (Unix ms), inclusive.
  ///
  /// Returns a [CashFlowReport] with three activity sections and the
  /// computed net cash flow.
  Future<CashFlowReport> generate(
    String companyId, {
    required int fromDateMs,
    required int toDateMs,
  }) async {
    // ── Fetch all relevant data in the date range ─────────────────────────
    final payments = await (db.select(db.payments)
          ..where((p) =>
              p.companyId.equals(companyId) &
              p.date.isBiggerOrEqualValue(fromDateMs) &
              p.date.isSmallerOrEqualValue(toDateMs) &
              p.status.equals('posted')))
        .get();

    final expenses = await (db.select(db.expenses)
          ..where((e) =>
              e.companyId.equals(companyId) &
              e.date.isBiggerOrEqualValue(fromDateMs) &
              e.date.isSmallerOrEqualValue(toDateMs) &
              e.status.equals('posted')))
        .get();

    final workerAdvances = await (db.select(db.workerAdvances)
          ..where((w) =>
              w.companyId.equals(companyId) &
              w.date.isBiggerOrEqualValue(fromDateMs) &
              w.date.isSmallerOrEqualValue(toDateMs) &
              w.status.equals('posted')))
        .get();

    final workerSalaries = await (db.select(db.workerSalaries)
          ..where((w) =>
              w.companyId.equals(companyId) &
              w.date.isBiggerOrEqualValue(fromDateMs) &
              w.date.isSmallerOrEqualValue(toDateMs) &
              w.status.equals('posted')))
        .get();

    final ownerWithdrawals = await (db.select(db.ownerWithdrawals)
          ..where((w) =>
              w.companyId.equals(companyId) &
              w.date.isBiggerOrEqualValue(fromDateMs) &
              w.date.isSmallerOrEqualValue(toDateMs) &
              w.status.equals('posted')))
        .get();

    final manufacturingJobs = await (db.select(db.manufacturingJobs)
          ..where((j) =>
              j.companyId.equals(companyId) &
              j.date.isBiggerOrEqualValue(fromDateMs) &
              j.date.isSmallerOrEqualValue(toDateMs) &
              j.status.equals('posted')))
        .get();

    // ── Categorize payments ───────────────────────────────────────────────
    final operatingLines = <CashFlowLine>[];
    final investingLines = <CashFlowLine>[];
    final financingLines = <CashFlowLine>[];

    for (final payment in payments) {
      if (payment.direction == 'incoming') {
        operatingLines.add(CashFlowLine(
          descriptionAr: 'مدفوعات العملاء',
          descriptionEn: 'Customer Payments',
          amount: payment.amount,
          dateMs: payment.date,
        ));
      } else if (payment.direction == 'outgoing') {
        operatingLines.add(CashFlowLine(
          descriptionAr: 'مدفوعات الموردين',
          descriptionEn: 'Supplier Payments',
          amount: -payment.amount,
          dateMs: payment.date,
        ));
      }
    }

    for (final expense in expenses) {
      operatingLines.add(CashFlowLine(
        descriptionAr: 'المصروفات',
        descriptionEn: 'Expenses',
        amount: -expense.amount,
        dateMs: expense.date,
      ));
    }

    for (final advance in workerAdvances) {
      operatingLines.add(CashFlowLine(
        descriptionAr: ' Advances العمال',
        descriptionEn: 'Worker Advances',
        amount: -advance.amount,
        dateMs: advance.date,
      ));
    }

    for (final salary in workerSalaries) {
      operatingLines.add(CashFlowLine(
        descriptionAr: 'رواتب العمال',
        descriptionEn: 'Worker Wages',
        amount: -salary.netPayment,
        dateMs: salary.date,
      ));
    }

    for (final job in manufacturingJobs) {
      investingLines.add(CashFlowLine(
        descriptionAr: 'تكاليف التصنيع',
        descriptionEn: 'Manufacturing Costs',
        amount: -job.totalCost,
        dateMs: job.date,
      ));
    }

    for (final withdrawal in ownerWithdrawals) {
      financingLines.add(CashFlowLine(
        descriptionAr: ' سحوبات المالك',
        descriptionEn: 'Owner Withdrawals',
        amount: -withdrawal.amount,
        dateMs: withdrawal.date,
      ));
    }

    operatingLines.sort((a, b) => a.dateMs.compareTo(b.dateMs));
    investingLines.sort((a, b) => a.dateMs.compareTo(b.dateMs));
    financingLines.sort((a, b) => a.dateMs.compareTo(b.dateMs));

    final operatingTotal =
        operatingLines.fold<int>(0, (sum, l) => sum + l.amount);
    final investingTotal =
        investingLines.fold<int>(0, (sum, l) => sum + l.amount);
    final financingTotal =
        financingLines.fold<int>(0, (sum, l) => sum + l.amount);

    final netCashFlow = operatingTotal + investingTotal + financingTotal;

    return CashFlowReport(
      operating: CashFlowSection(
        sectionNameAr: 'الأنشطة التشغيلية',
        sectionNameEn: 'Operating Activities',
        lines: operatingLines,
        total: operatingTotal,
      ),
      investing: CashFlowSection(
        sectionNameAr: 'الأنشطة الاستثمارية',
        sectionNameEn: 'Investing Activities',
        lines: investingLines,
        total: investingTotal,
      ),
      financing: CashFlowSection(
        sectionNameAr: 'الأنشطة التمويلية',
        sectionNameEn: 'Financing Activities',
        lines: financingLines,
        total: financingTotal,
      ),
      netCashFlow: netCashFlow,
    );
  }
}

/// Complete cash flow statement report with three activity sections
/// and the computed net cash flow.
@immutable
class CashFlowReport {
  final CashFlowSection operating;
  final CashFlowSection investing;
  final CashFlowSection financing;

  /// Net cash flow = Operating + Investing + Financing in minor units (x1000).
  final int netCashFlow;

  const CashFlowReport({
    required this.operating,
    required this.investing,
    required this.financing,
    required this.netCashFlow,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashFlowReport &&
          runtimeType == other.runtimeType &&
          operating == other.operating &&
          investing == other.investing &&
          financing == other.financing &&
          netCashFlow == other.netCashFlow;

  @override
  int get hashCode =>
      operating.hashCode ^
      investing.hashCode ^
      financing.hashCode ^
      netCashFlow.hashCode;
}

/// A grouped section of the cash flow statement (Operating, Investing, Financing).
///
/// Contains the section names in Arabic and English, the list of cash flow lines
/// within the section, and the computed section total.
@immutable
class CashFlowSection {
  final String sectionNameAr;
  final String sectionNameEn;
  final List<CashFlowLine> lines;
  final int total;

  const CashFlowSection({
    required this.sectionNameAr,
    required this.sectionNameEn,
    required this.lines,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashFlowSection &&
          runtimeType == other.runtimeType &&
          sectionNameAr == other.sectionNameAr &&
          sectionNameEn == other.sectionNameEn &&
          lines == other.lines &&
          total == other.total;

  @override
  int get hashCode =>
      sectionNameAr.hashCode ^
      sectionNameEn.hashCode ^
      lines.hashCode ^
      total.hashCode;
}

/// A single cash flow line item representing one cash movement.
///
/// Positive amounts represent cash inflows, negative amounts represent
/// cash outflows. All values are in minor units (x1000).
@immutable
class CashFlowLine {
  final String descriptionAr;
  final String descriptionEn;
  final int amount;
  final int dateMs;

  const CashFlowLine({
    required this.descriptionAr,
    required this.descriptionEn,
    required this.amount,
    required this.dateMs,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashFlowLine &&
          runtimeType == other.runtimeType &&
          descriptionAr == other.descriptionAr &&
          descriptionEn == other.descriptionEn &&
          amount == other.amount &&
          dateMs == other.dateMs;

  @override
  int get hashCode =>
      descriptionAr.hashCode ^
      descriptionEn.hashCode ^
      amount.hashCode ^
      dateMs.hashCode;
}

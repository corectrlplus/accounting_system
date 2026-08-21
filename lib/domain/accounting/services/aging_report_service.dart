import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Accounts receivable aging report (قائمة أعمار الذمم المدينة) service.
///
/// Shows how old outstanding customer balances are by categorizing them
/// into age buckets based on the time elapsed since the sale date:
/// - Current (0-30 days)
/// - 31-60 days
/// - 61-90 days
/// - Over 90 days
///
/// Only posted sales with credit amounts are considered. Outstanding balance
/// is calculated as totalAmount minus all allocated payment amounts.
///
/// All monetary values are in minor units (x1000).
@immutable
class AgingReportService {
  final AppDatabase db;

  const AgingReportService(this.db);

  /// Generate an accounts receivable aging report for the specified company.
  ///
  /// Parameters:
  /// - [companyId]: The company to generate the report for.
  /// - [reportDateMs]: The reference date for aging calculations (Unix ms).
  ///   Sale dates are compared against this date to determine the age bucket.
  ///
  /// Returns an [AgingReport] with per-customer lines showing outstanding
  /// balances broken down by age bucket, plus grand totals per bucket.
  Future<AgingReport> generate(
    String companyId, {
    required int reportDateMs,
  }) async {
    final sales = await (db.select(db.sales)
          ..where((s) =>
              s.companyId.equals(companyId) &
              s.creditAmount.equals(0).not() &
              s.status.equals('posted')))
        .get();

    final customerMap = <String, String>{};
    final customerLines = <String, AgingReportLine>{};

    for (final sale in sales) {
      final customerId = sale.customerId;
      if (customerId == null) continue;

      // Fetch customer name (cached per customer)
      if (!customerMap.containsKey(customerId)) {
        final customer = await (db.select(db.customers)
              ..where((c) =>
                  c.id.equals(customerId) & c.companyId.equals(companyId)))
            .getSingleOrNull();
        customerMap[customerId] = customer?.name ?? 'Unknown';
      }

      // Get total allocations for this sale
      final allocations = await (db.select(db.paymentAllocations)
            ..where((pa) =>
                pa.saleId.equals(sale.id) & pa.isDeleted.equals(false)))
          .get();

      final totalAllocated =
          allocations.fold<int>(0, (sum, a) => sum + a.allocatedAmount);

      final outstanding = sale.totalAmount - totalAllocated;
      if (outstanding <= 0) continue;

      // Calculate age in days
      final ageMs = reportDateMs - sale.date;
      final ageDays = ageMs ~/ (24 * 60 * 60 * 1000);

      int current = 0;
      int days31To60 = 0;
      int days61To90 = 0;
      int daysOver90 = 0;

      if (ageDays <= 30) {
        current = outstanding;
      } else if (ageDays <= 60) {
        days31To60 = outstanding;
      } else if (ageDays <= 90) {
        days61To90 = outstanding;
      } else {
        daysOver90 = outstanding;
      }

      if (customerLines.containsKey(customerId)) {
        final existing = customerLines[customerId]!;
        customerLines[customerId] = AgingReportLine(
          customerId: customerId,
          customerName: customerMap[customerId]!,
          totalOutstanding: existing.totalOutstanding + outstanding,
          current0to30: existing.current0to30 + current,
          days31to60: existing.days31to60 + days31To60,
          days61to90: existing.days61to90 + days61To90,
          daysOver90: existing.daysOver90 + daysOver90,
        );
      } else {
        customerLines[customerId] = AgingReportLine(
          customerId: customerId,
          customerName: customerMap[customerId]!,
          totalOutstanding: outstanding,
          current0to30: current,
          days31to60: days31To60,
          days61to90: days61To90,
          daysOver90: daysOver90,
        );
      }
    }

    final lines = customerLines.values.toList();
    lines.sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));

    final grandTotalOutstanding =
        lines.fold<int>(0, (sum, l) => sum + l.totalOutstanding);
    final grandCurrent =
        lines.fold<int>(0, (sum, l) => sum + l.current0to30);
    final grand31to60 =
        lines.fold<int>(0, (sum, l) => sum + l.days31to60);
    final grand61to90 =
        lines.fold<int>(0, (sum, l) => sum + l.days61to90);
    final grandOver90 =
        lines.fold<int>(0, (sum, l) => sum + l.daysOver90);

    return AgingReport(
      lines: lines,
      totalOutstanding: grandTotalOutstanding,
      totalCurrent0to30: grandCurrent,
      totalDays31to60: grand31to60,
      totalDays61to90: grand61to90,
      totalDaysOver90: grandOver90,
    );
  }
}

/// Complete accounts receivable aging report with per-customer lines
/// and grand totals for each age bucket.
@immutable
class AgingReport {
  final List<AgingReportLine> lines;

  /// Sum of all outstanding amounts across all customers.
  final int totalOutstanding;

  /// Sum of all current (0-30 days) outstanding amounts.
  final int totalCurrent0to30;

  /// Sum of all 31-60 day outstanding amounts.
  final int totalDays31to60;

  /// Sum of all 61-90 day outstanding amounts.
  final int totalDays61to90;

  /// Sum of all over 90 day outstanding amounts.
  final int totalDaysOver90;

  const AgingReport({
    required this.lines,
    required this.totalOutstanding,
    required this.totalCurrent0to30,
    required this.totalDays31to60,
    required this.totalDays61to90,
    required this.totalDaysOver90,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgingReport &&
          runtimeType == other.runtimeType &&
          lines == other.lines &&
          totalOutstanding == other.totalOutstanding &&
          totalCurrent0to30 == other.totalCurrent0to30 &&
          totalDays31to60 == other.totalDays31to60 &&
          totalDays61to90 == other.totalDays61to90 &&
          totalDaysOver90 == other.totalDaysOver90;

  @override
  int get hashCode =>
      lines.hashCode ^
      totalOutstanding.hashCode ^
      totalCurrent0to30.hashCode ^
      totalDays31to60.hashCode ^
      totalDays61to90.hashCode ^
      totalDaysOver90.hashCode;
}

/// A single customer line in the aging report showing the outstanding
/// balance broken down by age bucket.
@immutable
class AgingReportLine {
  final String customerId;
  final String customerName;

  /// Total outstanding amount in minor units (x1000).
  final int totalOutstanding;

  /// Outstanding amount aged 0-30 days in minor units (x1000).
  final int current0to30;

  /// Outstanding amount aged 31-60 days in minor units (x1000).
  final int days31to60;

  /// Outstanding amount aged 61-90 days in minor units (x1000).
  final int days61to90;

  /// Outstanding amount aged over 90 days in minor units (x1000).
  final int daysOver90;

  const AgingReportLine({
    required this.customerId,
    required this.customerName,
    required this.totalOutstanding,
    required this.current0to30,
    required this.days31to60,
    required this.days61to90,
    required this.daysOver90,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgingReportLine &&
          runtimeType == other.runtimeType &&
          customerId == other.customerId &&
          customerName == other.customerName &&
          totalOutstanding == other.totalOutstanding &&
          current0to30 == other.current0to30 &&
          days31to60 == other.days31to60 &&
          days61to90 == other.days61to90 &&
          daysOver90 == other.daysOver90;

  @override
  int get hashCode =>
      customerId.hashCode ^
      customerName.hashCode ^
      totalOutstanding.hashCode ^
      current0to30.hashCode ^
      days31to60.hashCode ^
      days61to90.hashCode ^
      daysOver90.hashCode;
}

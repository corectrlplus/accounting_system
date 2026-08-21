import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/accounting/services/aging_report_service.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen> {
  late final AppDatabase db;
  AgingReport? _report;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await AgingReportService(db).generate(
      'default',
      reportDateMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.agingReport),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? Center(child: Text(loc.noData))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1000,
                          child: DataTable(
                            columnSpacing: 12,
                            columns: [
                              DataColumn(label: Text(loc.customerCol)),
                              DataColumn(label: Text(loc.amountDue), numeric: true),
                              DataColumn(label: Text(loc.recent), numeric: true),
                              DataColumn(label: Text(loc.days31_60), numeric: true),
                              DataColumn(label: Text(loc.days61_90), numeric: true),
                              DataColumn(label: Text(loc.over90Days), numeric: true),
                            ],
                            rows: [
                              ..._report!.lines.map((line) => DataRow(cells: [
                                    DataCell(Text(line.customerName)),
                                    DataCell(Text(formatAmount(line.totalOutstanding))),
                                    DataCell(Text(formatAmount(line.current0to30))),
                                    DataCell(Text(formatAmount(line.days31to60))),
                                    DataCell(Text(formatAmount(line.days61to90))),
                                    DataCell(Text(
                                      formatAmount(line.daysOver90),
                                      style: TextStyle(
                                        color: line.daysOver90 > 0
                                            ? Colors.red[700]
                                            : null,
                                      ),
                                    )),
                                  ])),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        border: Border(
                          top: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.totalLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            formatAmount(_report!.totalOutstanding),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatAmount(_report!.totalCurrent0to30),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatAmount(_report!.totalDays31to60),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatAmount(_report!.totalDays61to90),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatAmount(_report!.totalDaysOver90),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _report!.totalDaysOver90 > 0
                                  ? Colors.red[700]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

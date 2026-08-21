import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/accounting/services/general_ledger_service.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';

class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  late final AppDatabase db;
  GeneralLedgerReport? _report;
  bool _loading = true;

  DateTime _fromDate = DateTime(2024);
  DateTime _toDate = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await GeneralLedgerService(db).generate(
      'default',
      fromDateMs: _fromDate.millisecondsSinceEpoch,
      toDateMs: _toDate.millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.generalLedger),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: loc.fromDate,
                    date: _fromDate,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: loc.toDate,
                    date: _toDate,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _report == null || _report!.entries.isEmpty
                    ? Center(child: Text(loc.noEntries))
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 900,
                                child: DataTable(
                                  columnSpacing: 12,
                                  columns: [
                                    DataColumn(label: Text(loc.entryNumber)),
                                    DataColumn(label: Text(loc.date)),
                                    DataColumn(label: Text(loc.descriptionCol)),
                                    DataColumn(label: Text(loc.accountCol)),
                                    DataColumn(label: Text(loc.debit), numeric: true),
                                    DataColumn(label: Text(loc.creditColumn), numeric: true),
                                  ],
                                  rows: _report!.entries
                                      .map(
                                        (e) => DataRow(cells: [
                                          DataCell(Text('${e.entryNumber}')),
                                          DataCell(Text(formatDate(e.dateMs))),
                                          DataCell(Text(
                                            e.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )),
                                          DataCell(Text(
                                            '${e.accountCode} - ${e.accountNameAr}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )),
                                          DataCell(Text(formatAmount(e.debitAmount))),
                                          DataCell(Text(formatAmount(e.creditAmount))),
                                        ]),
                                      )
                                      .toList(),
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
                                  formatAmount(_report!.totalDebit),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  formatAmount(_report!.totalCredit),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
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

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            formatDate(date.millisecondsSinceEpoch),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

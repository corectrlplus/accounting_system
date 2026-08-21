import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/accounting/services/trial_balance_service.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';

class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  late final AppDatabase db;
  List<TrialBalanceLine> _lines = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lines = await TrialBalanceService(db).generate('default');
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  int get _totalDebit => _lines.fold(0, (s, l) => s + l.totalDebit);
  int get _totalCredit => _lines.fold(0, (s, l) => s + l.totalCredit);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.trialBalance),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 800,
                      child: _lines.isEmpty
                          ? Center(child: Text(loc.noData))
                          : DataTable(
                              columnSpacing: 12,
                              columns: [
                                DataColumn(label: Text(loc.accountNumber)),
                                DataColumn(label: Text(loc.accountName)),
                                DataColumn(label: Text(loc.debit), numeric: true),
                                DataColumn(label: Text(loc.creditColumn), numeric: true),
                                DataColumn(label: Text(loc.balanceCol), numeric: true),
                              ],
                              rows: [
                                ..._lines.map((line) => DataRow(cells: [
                                      DataCell(Text(line.accountCode)),
                                      DataCell(Text(line.accountNameAr)),
                                      DataCell(Text(formatAmount(line.totalDebit))),
                                      DataCell(Text(formatAmount(line.totalCredit))),
                                      DataCell(Text(
                                        formatAmount(line.balance),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: line.balance >= 0
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                      )),
                                    ])),
                              ],
                            ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    border: Border(
                      top: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.totalLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Text(
                        formatAmount(_totalDebit),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        formatAmount(_totalCredit),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

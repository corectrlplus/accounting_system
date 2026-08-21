import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/accounting/services/income_statement_service.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';

class IncomeStatementScreen extends StatefulWidget {
  const IncomeStatementScreen({super.key});

  @override
  State<IncomeStatementScreen> createState() => _IncomeStatementScreenState();
}

class _IncomeStatementScreenState extends State<IncomeStatementScreen> {
  late final AppDatabase db;
  IncomeStatementReport? _report;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await IncomeStatementService(db).generate('default');
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
        title: Text(loc.incomeStatement),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? Center(child: Text(loc.noData))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(context, _report!.revenue),
                      const SizedBox(height: 16),
                      _buildSection(context, _report!.cogs),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        context,
                        title: loc.netProfit,
                        amount: _report!.grossProfit,
                        color: _report!.grossProfit >= 0
                            ? Colors.green[700]!
                            : Colors.red[700]!,
                      ),
                      const SizedBox(height: 16),
                      _buildSection(context, _report!.expenses),
                      const SizedBox(height: 24),
                      _buildSummaryCard(
                        context,
                        title: loc.netIncomeReport,
                        amount: _report!.netIncome,
                        color: _report!.netIncome >= 0
                            ? Colors.green[700]!
                            : Colors.red[700]!,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(BuildContext context, IncomeStatementSection section) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.sectionNameAr,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const Divider(),
            if (section.lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(loc.noAccounts),
              )
            else
              ...section.lines.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${line.accountCode} - ${line.accountNameAr}'),
                        ),
                        Text(
                          formatAmount(line.balance),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${loc.totalLabel} - ${section.sectionNameAr}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  formatCurrency(section.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required int amount,
    required Color color,
    bool isBold = false,
  }) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              amount >= 0 ? Icons.trending_up : Icons.trending_down,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isBold ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              formatCurrency(amount),
              style: TextStyle(
                fontSize: isBold ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

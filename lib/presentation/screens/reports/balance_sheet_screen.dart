import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/accounting/services/balance_sheet_service.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  late final AppDatabase db;
  BalanceSheetReport? _report;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await BalanceSheetService(db).generate('default');
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
        title: Text(loc.balanceSheet),
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
                      _buildSection(context, _report!.assets),
                      const SizedBox(height: 16),
                      _buildSection(context, _report!.liabilities),
                      const SizedBox(height: 16),
                      _buildSection(context, _report!.equity),
                      const SizedBox(height: 24),
                      _buildVerificationBanner(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(BuildContext context, BalanceSheetGroup group) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.sectionNameAr,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const Divider(),
            if (group.lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(loc.noAccounts),
              )
            else
              ...group.lines.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${line.accountCode} - ${line.accountNameAr}'),
                        ),
                        Text(
                          formatAmount(line.balance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: line.balance >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  )),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${loc.totalLabel} - ${group.sectionNameAr}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  formatCurrency(group.total),
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

  Widget _buildVerificationBanner(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isBalanced = _report!.isBalanced;

    return Card(
      color: isBalanced
          ? Colors.green[50]
          : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              isBalanced ? Icons.check_circle : Icons.error,
              size: 36,
              color: isBalanced ? Colors.green[700] : Colors.red[700],
            ),
            const SizedBox(height: 8),
            Text(
              isBalanced ? loc.balanced : loc.unbalanced,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isBalanced ? Colors.green[700] : Colors.red[700],
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(loc.assets, style: const TextStyle(fontSize: 12)),
                    Text(
                      formatCurrency(_report!.totalAssets),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Text('=', style: TextStyle(fontSize: 24)),
                Column(
                  children: [
                    Text(loc.liabilitiesEquity, style: const TextStyle(fontSize: 12)),
                    Text(
                      formatCurrency(_report!.totalLiabilitiesAndEquity),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

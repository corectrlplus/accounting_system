import 'package:flutter/material.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'trial_balance_screen.dart';
import 'balance_sheet_screen.dart';
import 'income_statement_screen.dart';
import 'general_ledger_screen.dart';
import 'aging_report_screen.dart';
import 'account_statement_screen.dart';

class ReportsListScreen extends StatelessWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.financialReports),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _ReportCard(
              title: loc.trialBalance,
              icon: Icons.balance,
              description: 'عرض أرصدة الحسابات المدينة والدائنة',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const TrialBalanceScreen()),
              ),
            ),
            _ReportCard(
              title: loc.balanceSheet,
              icon: Icons.account_balance,
              description: 'الأصول = الخصوم + حقوق الملكية',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const BalanceSheetScreen()),
              ),
            ),
            _ReportCard(
              title: loc.incomeStatement,
              icon: Icons.trending_up,
              description: 'الإيرادات والمصروفات وصافي الربح',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const IncomeStatementScreen()),
              ),
            ),
            _ReportCard(
              title: loc.generalLedger,
              icon: Icons.menu_book,
              description: 'سجل القيود اليومية التفصيلي',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const GeneralLedgerScreen()),
              ),
            ),
            _ReportCard(
              title: loc.agingReport,
              icon: Icons.schedule,
              description: 'تحليل أعمار حسابات العملاء',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const AgingReportScreen()),
              ),
            ),
            _ReportCard(
              title: loc.selectAccount,
              icon: Icons.receipt_long,
              description: 'كشف حساب تفصيلي لحساب محدد',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const AccountStatementScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

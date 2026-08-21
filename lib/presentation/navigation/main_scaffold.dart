import 'package:flutter/material.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/navigation/app_router.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:accounting_system/presentation/screens/settings/settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentTab = 0;

  Widget _buildTabContent(int index, bool isExpired) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return _buildTransactionsPlaceholder(isExpired);
      case 2:
        return _buildReportsPlaceholder();
      case 3:
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }

  Widget _buildTransactionsPlaceholder(bool isExpired) {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        if (isExpired) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الاشتراك منتهي',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800], fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يمكنك عرض السجلات السابقة فقط. لإضافة بيانات جديدة، يرجى تجديد الاشتراك.',
                        style: TextStyle(color: Colors.orange[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildTransactionCard(
          icon: Icons.shopping_cart,
          title: loc.sales,
          subtitle: loc.salesDesc,
          route: AppRouter.sales,
          blocked: isExpired,
        ),
        _buildTransactionCard(
          icon: Icons.shopping_bag,
          title: loc.purchases,
          subtitle: loc.purchasesDesc,
          route: AppRouter.purchases,
          blocked: isExpired,
        ),
        _buildTransactionCard(
          icon: Icons.payments,
          title: loc.payments,
          subtitle: loc.paymentsDesc,
          route: AppRouter.payments,
          blocked: isExpired,
        ),
        _buildTransactionCard(
          icon: Icons.receipt_long,
          title: loc.expenses,
          subtitle: loc.expensesDesc,
          route: AppRouter.expenses,
          blocked: isExpired,
        ),
        const Divider(height: 32),
        _buildTransactionCard(
          icon: Icons.people,
          title: loc.customers,
          subtitle: loc.customersDesc,
          route: AppRouter.customers,
          blocked: isExpired,
        ),
        _buildTransactionCard(
          icon: Icons.local_shipping,
          title: loc.suppliers,
          subtitle: loc.suppliersDesc,
          route: AppRouter.suppliers,
          blocked: isExpired,
        ),
        _buildTransactionCard(
          icon: Icons.engineering,
          title: loc.workers,
          subtitle: loc.workersDesc,
          route: AppRouter.workers,
          blocked: isExpired,
        ),
      ],
    );
  }

  Widget _buildTransactionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    bool blocked = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: blocked
              ? Colors.grey.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: blocked ? Colors.grey : Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: TextStyle(
          fontWeight: FontWeight.bold,
          color: blocked ? Colors.grey : null,
          decoration: blocked ? TextDecoration.lineThrough : null,
        )),
        subtitle: Text(blocked ? 'محدود - اشتراك منتهي' : subtitle, style: TextStyle(
          color: blocked ? Colors.orange[700] : null,
          fontSize: 12,
        )),
        trailing: Icon(blocked ? Icons.lock : Icons.chevron_left, color: blocked ? Colors.grey : null),
        onTap: blocked ? () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('اشتراك منتهي'),
              content: const Text('لا يمكن إضافة بيانات جديدة. يرجى تجديد الاشتراك للمتابعة.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        } : () {
          Navigator.of(context).pushNamed(route);
        },
      ),
    );
  }

  Widget _buildReportsPlaceholder() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        _buildReportCard(
          icon: Icons.balance,
          title: loc.trialBalance,
          route: AppRouter.trialBalance,
        ),
        _buildReportCard(
          icon: Icons.account_balance,
          title: loc.balanceSheet,
          route: AppRouter.balanceSheet,
        ),
        _buildReportCard(
          icon: Icons.trending_up,
          title: loc.incomeStatement,
          route: AppRouter.incomeStatement,
        ),
        _buildReportCard(
          icon: Icons.menu_book,
          title: loc.generalLedger,
          route: AppRouter.generalLedger,
        ),
        _buildReportCard(
          icon: Icons.date_range,
          title: loc.agingReport,
          route: AppRouter.aging,
        ),
        _buildReportCard(
          icon: Icons.account_balance_wallet,
          title: loc.cashFlowReport,
          route: AppRouter.cashFlow,
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
          child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isExpired = AppDatabaseProvider.isExpired(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appName),
        actions: [
          if (isExpired)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('اشتراك منتهي', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildTabContent(_currentTab, isExpired),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: loc.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt),
            label: loc.transactions,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assessment),
            label: loc.reports,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: loc.settings,
          ),
        ],
      ),
    );
  }
}

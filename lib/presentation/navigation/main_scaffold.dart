import 'package:flutter/material.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/navigation/app_router.dart';
import 'package:accounting_system/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:accounting_system/presentation/screens/settings/settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentTab = 0;

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return _buildTransactionsPlaceholder();
      case 2:
        return _buildReportsPlaceholder();
      case 3:
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }

  Widget _buildTransactionsPlaceholder() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        _buildTransactionCard(
          icon: Icons.shopping_cart,
          title: loc.sales,
          subtitle: loc.salesDesc,
          route: AppRouter.sales,
        ),
        _buildTransactionCard(
          icon: Icons.shopping_bag,
          title: loc.purchases,
          subtitle: loc.purchasesDesc,
          route: AppRouter.purchases,
        ),
        _buildTransactionCard(
          icon: Icons.payments,
          title: loc.payments,
          subtitle: loc.paymentsDesc,
          route: AppRouter.payments,
        ),
        _buildTransactionCard(
          icon: Icons.receipt_long,
          title: loc.expenses,
          subtitle: loc.expensesDesc,
          route: AppRouter.expenses,
        ),
        const Divider(height: 32),
        _buildTransactionCard(
          icon: Icons.people,
          title: loc.customers,
          subtitle: loc.customersDesc,
          route: AppRouter.customers,
        ),
        _buildTransactionCard(
          icon: Icons.local_shipping,
          title: loc.suppliers,
          subtitle: loc.suppliersDesc,
          route: AppRouter.suppliers,
        ),
        _buildTransactionCard(
          icon: Icons.engineering,
          title: loc.workers,
          subtitle: loc.workersDesc,
          route: AppRouter.workers,
        ),
      ],
    );
  }

  Widget _buildTransactionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildTabContent(_currentTab),
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

import 'package:flutter/material.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:accounting_system/presentation/screens/settings/settings_screen.dart';
import 'package:accounting_system/presentation/screens/transactions/sales_list_screen.dart';
import 'package:accounting_system/presentation/screens/transactions/purchases_list_screen.dart';
import 'package:accounting_system/presentation/screens/transactions/payments_list_screen.dart';
import 'package:accounting_system/presentation/screens/transactions/expenses_list_screen.dart';
import 'package:accounting_system/presentation/screens/masters/customers_list_screen.dart';
import 'package:accounting_system/presentation/screens/masters/suppliers_list_screen.dart';
import 'package:accounting_system/presentation/screens/masters/workers_list_screen.dart';
import 'package:accounting_system/presentation/screens/reports/trial_balance_screen.dart';
import 'package:accounting_system/presentation/screens/reports/balance_sheet_screen.dart';
import 'package:accounting_system/presentation/screens/reports/income_statement_screen.dart';
import 'package:accounting_system/presentation/screens/reports/general_ledger_screen.dart';
import 'package:accounting_system/presentation/screens/reports/aging_report_screen.dart';
import 'package:accounting_system/presentation/screens/reports/reports_list_screen.dart';

class AppRouter {
  static const String dashboard = '/dashboard';
  static const String sales = '/sales';
  static const String purchases = '/purchases';
  static const String payments = '/payments';
  static const String paymentsIncoming = '/payments/incoming';
  static const String paymentsOutgoing = '/payments/outgoing';
  static const String expenses = '/expenses';
  static const String customers = '/customers';
  static const String suppliers = '/suppliers';
  static const String workers = '/workers';
  static const String trialBalance = '/reports/trial-balance';
  static const String balanceSheet = '/reports/balance-sheet';
  static const String incomeStatement = '/reports/income-statement';
  static const String generalLedger = '/reports/general-ledger';
  static const String aging = '/reports/aging';
  static const String cashFlow = '/reports/cash-flow';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case dashboard:
        return _buildRoute(const DashboardScreen(), routeSettings);
      case sales:
        return _buildRoute(const SalesListScreen(), routeSettings);
      case purchases:
        return _buildRoute(const PurchasesListScreen(), routeSettings);
      case payments:
        return _buildRoute(
          const _PaymentsChooserScreen(),
          routeSettings,
        );
      case paymentsIncoming:
        return _buildRoute(
          const PaymentsListScreen(direction: PaymentDirection.incoming),
          routeSettings,
        );
      case paymentsOutgoing:
        return _buildRoute(
          const PaymentsListScreen(direction: PaymentDirection.outgoing),
          routeSettings,
        );
      case expenses:
        return _buildRoute(const ExpensesListScreen(), routeSettings);
      case customers:
        return _buildRoute(const CustomersListScreen(), routeSettings);
      case suppliers:
        return _buildRoute(const SuppliersListScreen(), routeSettings);
      case workers:
        return _buildRoute(const WorkersListScreen(), routeSettings);
      case trialBalance:
        return _buildRoute(const TrialBalanceScreen(), routeSettings);
      case balanceSheet:
        return _buildRoute(const BalanceSheetScreen(), routeSettings);
      case incomeStatement:
        return _buildRoute(const IncomeStatementScreen(), routeSettings);
      case generalLedger:
        return _buildRoute(const GeneralLedgerScreen(), routeSettings);
      case aging:
        return _buildRoute(const AgingReportScreen(), routeSettings);
      case cashFlow:
        return _buildRoute(const ReportsListScreen(), routeSettings);
      case settings:
        return _buildRoute(const SettingsScreen(), routeSettings);
      default:
        return _buildRoute(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Text(
                  AppLocalizations.of(context).pageNotFound,
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ),
            ),
          ),
          routeSettings,
        );
    }
  }

  static PageRouteBuilder _buildRoute(Widget child, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}

class _PaymentsChooserScreen extends StatelessWidget {
  const _PaymentsChooserScreen();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.payments)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                child: const Icon(Icons.arrow_downward, color: Colors.green),
              ),
              title: Text(loc.incomingPayments, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(loc.incomingPaymentsDesc),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.pushNamed(context, AppRouter.paymentsIncoming),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                child: const Icon(Icons.arrow_upward, color: Colors.red),
              ),
              title: Text(loc.outgoingPayments, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(loc.outgoingPaymentsDesc),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.pushNamed(context, AppRouter.paymentsOutgoing),
            ),
          ),
        ],
      ),
    );
  }
}

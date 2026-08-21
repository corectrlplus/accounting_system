import 'package:flutter/material.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

import 'sales_list_screen.dart';
import 'purchases_list_screen.dart';
import 'payments_list_screen.dart';
import 'expenses_list_screen.dart';

class TransactionsListScreen extends StatelessWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final categories = _buildCategories(loc);
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: cat.onTap != null
                  ? () => Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: cat.onTap!),
                      )
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cat.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cat.icon, color: cat.iconColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }
}

class _TransactionCategory {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final WidgetBuilder? onTap;

  const _TransactionCategory({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

List<_TransactionCategory> _buildCategories(AppLocalizations loc) {
  return [
    _TransactionCategory(
      icon: Icons.shopping_cart_outlined,
      iconColor: const Color(0xFF43A047),
      title: loc.sales,
      subtitle: loc.salesDesc,
      onTap: _buildSalesList,
    ),
    _TransactionCategory(
      icon: Icons.shopping_bag_outlined,
      iconColor: const Color(0xFF1E88E5),
      title: loc.purchases,
      subtitle: loc.purchasesDesc,
      onTap: _buildPurchasesList,
    ),
    _TransactionCategory(
      icon: Icons.payments_outlined,
      iconColor: const Color(0xFFFFB300),
      title: loc.customerPayments,
      subtitle: loc.incomingPaymentsDesc,
      onTap: _buildIncomingPayments,
    ),
    _TransactionCategory(
      icon: Icons.money_off_csred_outlined,
      iconColor: const Color(0xFFE53935),
      title: loc.supplierPayments,
      subtitle: loc.outgoingPaymentsDesc,
      onTap: _buildOutgoingPayments,
    ),
    _TransactionCategory(
      icon: Icons.receipt_long_outlined,
      iconColor: const Color(0xFF8E24AA),
      title: loc.expenses,
      subtitle: loc.expensesDesc,
      onTap: _buildExpensesList,
    ),
    const _TransactionCategory(
      icon: Icons.savings_outlined,
      iconColor: Color(0xFF00897B),
      title: 'Worker Advances',
      subtitle: 'Record worker advances and loans',
    ),
    const _TransactionCategory(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: Color(0xFF5C6BC0),
      title: 'Worker Salaries',
      subtitle: 'Pay worker salaries with advance deduction',
    ),
    const _TransactionCategory(
      icon: Icons.upload_outlined,
      iconColor: Color(0xFF6D4C41),
      title: 'Owner Withdrawals',
      subtitle: 'Record owner withdrawals from capital',
    ),
  ];
}

Widget _buildSalesList(BuildContext context) => const SalesListScreen();
Widget _buildPurchasesList(BuildContext context) => const PurchasesListScreen();
Widget _buildIncomingPayments(BuildContext context) =>
    const PaymentsListScreen(direction: PaymentDirection.incoming);
Widget _buildOutgoingPayments(BuildContext context) =>
    const PaymentsListScreen(direction: PaymentDirection.outgoing);
Widget _buildExpensesList(BuildContext context) => const ExpensesListScreen();

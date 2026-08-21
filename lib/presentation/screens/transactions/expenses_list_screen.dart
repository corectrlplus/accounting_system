import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

import 'expense_form_screen.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  late AppDatabase _db;
  List<_ExpenseRow> _expenses = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final loc = AppLocalizations.of(context);

    final rows = await (_db.select(_db.expenses)
          ..where((e) => e.isDeleted.equals(false))
          ..orderBy([(e) => drift.OrderingTerm.desc(e.date)]))
        .get();

    final result = <_ExpenseRow>[];
    for (final expense in rows) {
      String categoryName = loc.uncategorized;
      final cat = await (_db.select(_db.expenseCategories)
            ..where((c) => c.id.equals(expense.expenseCategoryId)))
          .getSingleOrNull();
      if (cat != null) categoryName = cat.nameAr;
      result.add(_ExpenseRow(expense: expense, categoryName: categoryName));
    }

    if (!mounted) return;
    setState(() {
      _expenses = result;
      _loading = false;
    });
  }

  String _methodLabel(String method, AppLocalizations loc) {
    switch (method) {
      case 'cash':
        return loc.cash;
      case 'bank':
        return loc.bank;
      default:
        return method;
    }
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'cash':
        return const Color(0xFF43A047);
      case 'bank':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(loc.expenses)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          loc.noExpenses,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.tapPlusToAddExpense,
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final row = _expenses[index];
                        final e = row.expense;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF8E24AA).withValues(alpha: 0.1),
                              child: Text(
                                '${e.expenseNumber}',
                                style: const TextStyle(
                                  color: Color(0xFF8E24AA),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              row.categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDate(e.date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _methodColor(e.paymentMethod).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _methodLabel(e.paymentMethod, loc),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _methodColor(e.paymentMethod),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              formatCurrency(e.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
            );
            if (result == true) _load();
          },
          icon: const Icon(Icons.add),
          label: Text(loc.addNewExpense),
        ),
      );
  }
}

class _ExpenseRow {
  final ExpenseData expense;
  final String categoryName;
  const _ExpenseRow({required this.expense, required this.categoryName});
}

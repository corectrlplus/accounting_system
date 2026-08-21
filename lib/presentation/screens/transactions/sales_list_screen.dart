import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

import 'sale_form_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  late AppDatabase _db;
  List<_SaleRow> _sales = [];
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

    final saleRows = await (_db.select(_db.sales)
          ..where((s) => s.isDeleted.equals(false))
          ..orderBy([(s) => drift.OrderingTerm.desc(s.date)]))
        .get();

    final rows = <_SaleRow>[];
    for (final sale in saleRows) {
      String customerName = loc.generalCustomer;
      if (sale.customerId != null) {
        final c = await (_db.select(_db.customers)
              ..where((cu) => cu.id.equals(sale.customerId!)))
            .getSingleOrNull();
        if (c != null) customerName = c.name;
      }
      rows.add(_SaleRow(sale: sale, customerName: customerName));
    }

    if (!mounted) return;
    setState(() {
      _sales = rows;
      _loading = false;
    });
  }

  String _paymentLabel(String type, AppLocalizations loc) {
    switch (type) {
      case 'cash':
        return loc.cash;
      case 'credit':
        return loc.credit;
      case 'mixed':
        return loc.mixed;
      default:
        return type;
    }
  }

  Color _paymentColor(String type) {
    switch (type) {
      case 'cash':
        return const Color(0xFF43A047);
      case 'credit':
        return const Color(0xFFFFB300);
      case 'mixed':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(loc.sales)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _sales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.noSales,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.tapPlusToAddSale,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _load();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sales.length,
                      itemBuilder: (context, index) {
                        final row = _sales[index];
                        final sale = row.sale;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              child: Text(
                                '${sale.saleNumber}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              row.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDate(sale.date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _paymentColor(sale.paymentType).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _paymentLabel(sale.paymentType, loc),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _paymentColor(sale.paymentType),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              formatCurrency(sale.totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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
              MaterialPageRoute(builder: (_) => const SaleFormScreen()),
            );
            if (result == true) _load();
          },
          icon: const Icon(Icons.add),
          label: Text(loc.addNewSale),
        ),
      );
  }
}

class _SaleRow {
  final SaleData sale;
  final String customerName;
  const _SaleRow({required this.sale, required this.customerName});
}

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

import 'purchase_form_screen.dart';

class PurchasesListScreen extends StatefulWidget {
  const PurchasesListScreen({super.key});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  late AppDatabase _db;
  List<_PurchaseRow> _purchases = [];
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

    final rows = await (_db.select(_db.purchases)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => drift.OrderingTerm.desc(p.date)]))
        .get();

    final result = <_PurchaseRow>[];
    for (final purchase in rows) {
      String supplierName = loc.generalSupplier;
      if (purchase.supplierId != null) {
        final s = await (_db.select(_db.suppliers)
              ..where((su) => su.id.equals(purchase.supplierId!)))
            .getSingleOrNull();
        if (s != null) supplierName = s.name;
      }
      result.add(_PurchaseRow(purchase: purchase, supplierName: supplierName));
    }

    if (!mounted) return;
    setState(() {
      _purchases = result;
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

  String _natureLabel(String nature, AppLocalizations loc) {
    switch (nature) {
      case 'inventory':
        return loc.inventory;
      case 'materials':
        return loc.materials;
      case 'operating_expense':
        return loc.operatingExpense;
      case 'service':
        return loc.service;
      default:
        return nature;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(loc.purchases)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _purchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          loc.noPurchases,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.tapPlusToAddPurchase,
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _purchases.length,
                      itemBuilder: (context, index) {
                        final row = _purchases[index];
                        final p = row.purchase;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                              child: Text(
                                '${p.purchaseNumber}',
                                style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              row.supplierName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(formatDate(p.date), style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _paymentColor(p.paymentType).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _paymentLabel(p.paymentType, loc),
                                      style: TextStyle(fontSize: 11, color: _paymentColor(p.paymentType), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _natureLabel(p.accountingNature, loc),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              formatCurrency(p.totalAmount),
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
              MaterialPageRoute(builder: (_) => const PurchaseFormScreen()),
            );
            if (result == true) _load();
          },
          icon: const Icon(Icons.add),
          label: Text(loc.addNewPurchase),
        ),
      );
  }
}

class _PurchaseRow {
  final PurchaseData purchase;
  final String supplierName;
  const _PurchaseRow({required this.purchase, required this.supplierName});
}

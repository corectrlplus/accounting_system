import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/screens/masters/supplier_form_screen.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;

class SuppliersListScreen extends StatefulWidget {
  const SuppliersListScreen({super.key});

  @override
  State<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends State<SuppliersListScreen> {
  late final AppDatabase db;
  List<Supplier> _suppliers = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final suppliers = await (db.select(db.suppliers)
          ..where((s) => s.isActive.equals(true) & s.isDeleted.equals(false))
          ..orderBy([(s) => drift.OrderingTerm.asc(s.name)]))
        .get();
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _loading = false;
    });
  }

  Future<int> _getBalance(String accountId) async {
    return db.getDerivedAccountBalance(accountId);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.suppliers),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? Center(child: Text(loc.noSuppliers))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.local_shipping,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        title: Text(
                          supplier.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (supplier.phone != null && supplier.phone!.isNotEmpty)
                              Text('${loc.phone}: ${supplier.phone}'),
                            FutureBuilder<int>(
                              future: _getBalance(supplier.accountId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                final balance = snapshot.data!;
                                return Text(
                                  '${loc.balance}: ${formatCurrency(balance)}',
                                  style: TextStyle(
                                    color: balance > 0 ? Colors.red[700] : Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupplierFormScreen(supplier: supplier),
                            ),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

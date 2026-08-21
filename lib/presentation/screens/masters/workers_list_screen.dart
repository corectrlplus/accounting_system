import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/screens/masters/worker_form_screen.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;

class WorkersListScreen extends StatefulWidget {
  const WorkersListScreen({super.key});

  @override
  State<WorkersListScreen> createState() => _WorkersListScreenState();
}

class _WorkersListScreenState extends State<WorkersListScreen> {
  late final AppDatabase db;
  List<Worker> _workers = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final workers = await (db.select(db.workers)
          ..where((w) => w.isActive.equals(true) & w.isDeleted.equals(false))
          ..orderBy([(w) => drift.OrderingTerm.asc(w.name)]))
        .get();
    if (!mounted) return;
    setState(() {
      _workers = workers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.workers),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const WorkerFormScreen()),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workers.isEmpty
              ? Center(child: Text(loc.noWorkers))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _workers.length,
                  itemBuilder: (context, index) {
                    final worker = _workers[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.engineering,
                            color: Colors.orange,
                          ),
                        ),
                        title: Text(
                          worker.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (worker.phone != null && worker.phone!.isNotEmpty)
                              Text('${loc.phone}: ${worker.phone}'),
                            if (worker.dailyRate != null)
                              Text(
                                '${loc.dailyRate}: ${formatCurrency(worker.dailyRate!)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkerFormScreen(worker: worker),
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

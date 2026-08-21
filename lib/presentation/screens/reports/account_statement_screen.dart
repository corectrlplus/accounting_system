import 'package:flutter/material.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/domain/accounting/services/account_statement_service.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:drift/drift.dart' as drift;

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  late final AppDatabase db;
  List<AccountStatementLine> _lines = [];
  List<Account> _accounts = [];
  Account? _selectedAccount;
  bool _loading = false;

  DateTime _fromDate = DateTime(2024);
  DateTime _toDate = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await (db.select(db.accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => drift.OrderingTerm.asc(a.code)]))
        .get();
    if (!mounted) return;
    setState(() => _accounts = accounts);
  }

  Future<void> _load() async {
    if (_selectedAccount == null) return;
    setState(() => _loading = true);
    final lines = await AccountStatementService(db).getAccountStatement(
      _selectedAccount!.id,
      fromDateMs: _fromDate.millisecondsSinceEpoch,
      toDateMs: _toDate.millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      if (_selectedAccount != null) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.selectAccount),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<Account>(
                  decoration: InputDecoration(
                    labelText: loc.selectAccountHint,
                  ),
                  initialValue: _selectedAccount,
                  items: _accounts
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text('${a.code} - ${a.nameAr}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedAccount = val);
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: loc.fromDate,
                        date: _fromDate,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateButton(
                        label: loc.toDate,
                        date: _toDate,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _selectedAccount == null
                    ? Center(child: Text(loc.selectAccountHint))
                    : _lines.isEmpty
                        ? Center(child: Text(loc.noMovements))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 900,
                              child: DataTable(
                                columnSpacing: 12,
                                columns: [
                                  DataColumn(label: Text(loc.date)),
                                  DataColumn(label: Text(loc.descriptionCol)),
                                  DataColumn(label: Text(loc.debit), numeric: true),
                                  DataColumn(label: Text(loc.creditColumn), numeric: true),
                                  DataColumn(label: Text(loc.runningBalance), numeric: true),
                                ],
                                rows: [
                                  ..._lines.map((line) => DataRow(cells: [
                                        DataCell(Text(formatDate(line.dateMs))),
                                        DataCell(Text(
                                          line.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                        DataCell(Text(formatAmount(line.debitAmount))),
                                        DataCell(Text(formatAmount(line.creditAmount))),
                                        DataCell(Text(
                                          formatAmount(line.runningBalance),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: line.runningBalance >= 0
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                          ),
                                        )),
                                      ])),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            formatDate(date.millisecondsSinceEpoch),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

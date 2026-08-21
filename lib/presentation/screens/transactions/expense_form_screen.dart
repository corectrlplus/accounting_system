import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedCategoryId;
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  late AppDatabase _db;
  late AppLocalizations _loc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = AppDatabaseProvider.of(context);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final expenseId = const Uuid().v4();
      final idempotencyKey = '${expenseId}_${now.millisecondsSinceEpoch}';
      final companyId = 'default_company';

      final amount = int.tryParse(_amountCtrl.text) ?? 0;

      final lastExpense = await (_db.select(_db.expenses)
            ..where((e) => e.companyId.equals(companyId))
            ..limit(1)
            ..orderBy([(e) => drift.OrderingTerm.desc(e.expenseNumber)]))
          .getSingleOrNull();
      final nextNumber = (lastExpense?.expenseNumber ?? 0) + 1;

      await _db.into(_db.expenses).insert(
            ExpensesCompanion.insert(
              id: expenseId,
              companyId: companyId,
              expenseNumber: nextNumber,
              date: _selectedDate.millisecondsSinceEpoch,
              amount: amount,
              expenseCategoryId: _selectedCategoryId!,
              paymentMethod: _paymentMethod,
              description: drift.Value(_descCtrl.text.isEmpty ? null : _descCtrl.text),
              currencyCode: const drift.Value('IQD'),
              journalEntryId: '',
              status: const drift.Value('posted'),
              createdBy: 'system',
              idempotencyKey: idempotencyKey,
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
              deviceId: 'local',
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loc.expenseSaved)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _loc = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(_loc.addNewExpense)),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Amount
              TextFormField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                  labelText: _loc.amount,
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: 'د.ع',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(),
                validator: (v) {
                  if (v == null || v.isEmpty) return _loc.enterAmount;
                  final val = int.tryParse(v);
                  if (val == null || val <= 0) return _loc.amountMustBePositive;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              FutureBuilder<List<ExpenseCategory>>(
                future: (_db.select(_db.expenseCategories)
                      ..where((c) => c.isDeleted.equals(false) & c.isActive.equals(true)))
                    .get(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: _loc.category,
                      hintText: _loc.selectCategory,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: categories.map(
                      (c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.nameAr, style: const TextStyle()),
                      ),
                    ).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? _loc.selectCategoryValidation : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _loc.date,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(formatDate(_selectedDate.millisecondsSinceEpoch)),
                ),
              ),
              const SizedBox(height: 16),

              // Payment method
              Text(
                _loc.paymentMethod,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      
                    ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'cash',
                    label: Text(_loc.cash, style: const TextStyle()),
                    icon: const Icon(Icons.money),
                  ),
                  ButtonSegment(
                    value: 'bank',
                    label: Text(_loc.bank, style: const TextStyle()),
                    icon: const Icon(Icons.account_balance),
                  ),
                ],
                selected: {_paymentMethod},
                onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: _loc.description,
                  hintText: _loc.descriptionOptional,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.notes),
                ),
                style: const TextStyle(),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Save
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _saving ? _loc.saving : _loc.saveExpense,
                  style: const TextStyle(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
    );
  }
}

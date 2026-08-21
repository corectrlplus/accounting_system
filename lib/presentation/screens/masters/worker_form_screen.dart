import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class WorkerFormScreen extends StatefulWidget {
  const WorkerFormScreen({super.key, this.worker});

  final Worker? worker;

  @override
  State<WorkerFormScreen> createState() => _WorkerFormScreenState();
}

class _WorkerFormScreenState extends State<WorkerFormScreen> {
  late final AppDatabase db;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dailyRateController = TextEditingController();
  final _advanceController = TextEditingController();

  bool get _isEditing => widget.worker != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.worker!.name;
      _phoneController.text = widget.worker!.phone ?? '';
      if (widget.worker!.dailyRate != null) {
        _dailyRateController.text = formatAmount(widget.worker!.dailyRate!);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    db = AppDatabaseProvider.of(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dailyRateController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  int _parseAmount(String text) {
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();
    final dailyRate = _parseAmount(_dailyRateController.text);

    if (_isEditing) {
      await (db.update(db.workers)
            ..where((w) => w.id.equals(widget.worker!.id)))
          .write(WorkersCompanion(
            name: Value(_nameController.text.trim()),
            phone: Value(_phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim()),
            dailyRate: Value(dailyRate > 0 ? dailyRate : null),
            updatedAt: Value(now),
          ));
    } else {
      final workerId = uuid.v4();
      await db.into(db.workers).insert(
        WorkersCompanion.insert(
          id: workerId,
          companyId: 'default',
          name: _nameController.text.trim(),
          phone: Value(_phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim()),
          dailyRate: Value(dailyRate > 0 ? dailyRate : null),
          accountId: uuid.v4(),
          createdAt: now,
          updatedAt: now,
          deviceId: 'local',
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? loc.editWorker : loc.addNewWorker),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.name,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.enterName;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: loc.phoneLabel,
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyRateController,
                decoration: InputDecoration(
                  labelText: loc.dailyWage,
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final amount = _parseAmount(value);
                    if (amount < 0) {
                      return loc.amountMustBePositive;
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _advanceController,
                decoration: InputDecoration(
                  labelText: loc.advanceAmount,
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? loc.saveChanges : loc.addWorker),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

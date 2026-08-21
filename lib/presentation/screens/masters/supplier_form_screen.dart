import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  late final AppDatabase db;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.supplier!.name;
      _phoneController.text = widget.supplier!.phone ?? '';
      _addressController.text = widget.supplier!.address ?? '';
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
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();

    if (_isEditing) {
      await (db.update(db.suppliers)
            ..where((s) => s.id.equals(widget.supplier!.id)))
          .write(SuppliersCompanion(
            name: Value(_nameController.text.trim()),
            phone: Value(_phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim()),
            address: Value(_addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim()),
            updatedAt: Value(now),
          ));
    } else {
      final supplierId = uuid.v4();
      await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(
          id: supplierId,
          companyId: 'default',
          name: _nameController.text.trim(),
          phone: Value(_phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim()),
          address: Value(_addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim()),
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
        title: Text(_isEditing ? loc.editSupplier : loc.addNewSupplier),
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
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: loc.address,
                  prefixIcon: const Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? loc.saveChanges : loc.addSupplier),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

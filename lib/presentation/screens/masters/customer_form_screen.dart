import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  late final AppDatabase db;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone ?? '';
      _addressController.text = widget.customer!.address ?? '';
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
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();

    if (_isEditing) {
      await (db.update(db.customers)
            ..where((c) => c.id.equals(widget.customer!.id)))
          .write(CustomersCompanion(
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
      final customerId = uuid.v4();
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: customerId,
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
        title: Text(_isEditing ? loc.editCustomer : loc.addNewCustomer),
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
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: loc.email,
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
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
                label: Text(_isEditing ? loc.saveChanges : loc.addCustomer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

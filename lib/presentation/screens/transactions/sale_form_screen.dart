import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  DateTime _selectedDate = DateTime.now();
  String _paymentType = 'cash';
  final _cashReceivedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_LineItem> _items = [_LineItem()];
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
    _cashReceivedCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_LineItem()));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  int get _totalMinor {
    int total = 0;
    for (final item in _items) {
      final qty = int.tryParse(item.qtyCtrl.text) ?? 0;
      final price = int.tryParse(item.priceCtrl.text) ?? 0;
      total += qty * price;
    }
    return total;
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
      final saleId = const Uuid().v4();
      final idempotencyKey = '${saleId}_${now.millisecondsSinceEpoch}';
      final companyId = 'default_company';

      final total = _totalMinor;
      int cashReceived = 0;
      int creditAmount = 0;

      if (_paymentType == 'cash') {
        cashReceived = total;
      } else if (_paymentType == 'credit') {
        creditAmount = total;
      } else {
        cashReceived = int.tryParse(_cashReceivedCtrl.text) ?? 0;
        creditAmount = total - cashReceived;
      }

      final lastSale = await (_db.select(_db.sales)
            ..where((s) => s.companyId.equals(companyId))
            ..limit(1)
            ..orderBy([(s) => drift.OrderingTerm.desc(s.saleNumber)]))
          .getSingleOrNull();
      final nextNumber = (lastSale?.saleNumber ?? 0) + 1;

      await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              companyId: companyId,
              customerId: drift.Value(_selectedCustomerId),
              saleNumber: nextNumber,
              date: _selectedDate.millisecondsSinceEpoch,
              totalAmount: total,
              cashReceived: drift.Value(cashReceived),
              creditAmount: drift.Value(creditAmount),
              paymentType: _paymentType,
              currencyCode: const drift.Value('IQD'),
              journalEntryId: '',
              status: const drift.Value('posted'),
              notes: drift.Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
              createdBy: 'system',
              idempotencyKey: idempotencyKey,
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
              deviceId: 'local',
            ),
          );

      for (int i = 0; i < _items.length; i++) {
        final it = _items[i];
        final desc = it.descCtrl.text;
        final qty = int.tryParse(it.qtyCtrl.text) ?? 0;
        final price = int.tryParse(it.priceCtrl.text) ?? 0;
        if (desc.isNotEmpty && qty > 0 && price > 0) {
          await _db.into(_db.saleItems).insert(
                SaleItemsCompanion.insert(
                  id: const Uuid().v4(),
                  companyId: companyId,
                  saleId: saleId,
                  description: desc,
                  quantity: qty,
                  unitPrice: price,
                  totalPrice: qty * price,
                  sortOrder: drift.Value(i),
                  createdAt: now.millisecondsSinceEpoch,
                ),
              );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loc.saleSaved)),
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
        appBar: AppBar(title: Text(_loc.addNewSale)),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCustomerDropdown(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 24),
              _buildItemsSection(),
              const SizedBox(height: 24),
              _buildPaymentTypeSection(),
              const SizedBox(height: 16),
              _buildNotesField(),
              const SizedBox(height: 24),
              _buildTotalBar(),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
    );
  }

  Widget _buildCustomerDropdown() {
    return FutureBuilder<List<Customer>>(
      future: (_db.select(_db.customers)
            ..where((c) => c.isDeleted.equals(false) & c.isActive.equals(true)))
          .get(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? [];
        return DropdownButtonFormField<String>(
          value: _selectedCustomerId,
          decoration: InputDecoration(
            labelText: _loc.customer,
            hintText: _loc.selectCustomerOptional,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(_loc.generalCustomer, style: const TextStyle()),
            ),
            ...customers.map(
              (c) => DropdownMenuItem<String>(
                value: c.id,
                child: Text(c.name, style: const TextStyle()),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedCustomerId = v),
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _loc.date,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(formatDate(_selectedDate.millisecondsSinceEpoch)),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _loc.items,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    
                  ),
            ),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(_loc.addItem, style: const TextStyle()),
            ),
          ],
        ),
        ...List.generate(_items.length, (i) {
          final item = _items[i];
          final itemTotal = (int.tryParse(item.qtyCtrl.text) ?? 0) *
              (int.tryParse(item.priceCtrl.text) ?? 0);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _loc.itemNumber(i + 1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          
                        ),
                      ),
                      if (_items.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _removeItem(i),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: item.descCtrl,
                    decoration: InputDecoration(
                      labelText: _loc.description,
                      hintText: _loc.itemDescription,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? _loc.enterDescription : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: item.qtyCtrl,
                          decoration: InputDecoration(
                            labelText: _loc.quantity,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(),
                          onChanged: (_) => setState(() {}),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? _loc.required : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: item.priceCtrl,
                          decoration: InputDecoration(
                            labelText: _loc.unitPrice,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixText: 'د.ع',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(),
                          onChanged: (_) => setState(() {}),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? _loc.required : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      _loc.totalAmount(formatCurrency(itemTotal)),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _loc.paymentType,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                
              ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'cash', label: Text(_loc.cash, style: const TextStyle())),
            ButtonSegment(value: 'credit', label: Text(_loc.credit, style: const TextStyle())),
            ButtonSegment(value: 'mixed', label: Text(_loc.mixed, style: const TextStyle())),
          ],
          selected: {_paymentType},
          onSelectionChanged: (s) => setState(() => _paymentType = s.first),
        ),
        if (_paymentType == 'mixed') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _cashReceivedCtrl,
            decoration: InputDecoration(
              labelText: _loc.cashReceived,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.money),
              suffixText: 'د.ع',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (_paymentType != 'mixed') return null;
              if (v == null || v.isEmpty) return _loc.enterCashAmount;
              final cash = int.tryParse(v) ?? 0;
              if (cash <= 0) return _loc.amountMustBePositive;
              if (cash >= _totalMinor) return _loc.cashMustBeLessThanTotal;
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesCtrl,
      decoration: InputDecoration(
        labelText: _loc.notes,
        hintText: _loc.additionalNotesOptional,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.notes),
      ),
      style: const TextStyle(),
      maxLines: 3,
    );
  }

  Widget _buildTotalBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _loc.total,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  
                ),
          ),
          Text(
            formatCurrency(_totalMinor),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save),
      label: Text(
        _saving ? _loc.saving : _loc.saveSale,
        style: const TextStyle(),
      ),
    );
  }
}

class _LineItem {
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:accounting_system/data/database/app_database.dart';
import 'package:accounting_system/presentation/providers/app_provider.dart';
import 'package:accounting_system/presentation/utils/format_utils.dart';
import 'package:accounting_system/l10n/app_localizations.dart';

enum PaymentDirection { incoming, outgoing }

class PaymentsListScreen extends StatefulWidget {
  final PaymentDirection direction;

  const PaymentsListScreen({super.key, required this.direction});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  late AppDatabase _db;
  List<_PaymentRow> _payments = [];
  bool _loading = true;

  bool get _isIncoming => widget.direction == PaymentDirection.incoming;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = AppDatabaseProvider.of(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final loc = AppLocalizations.of(context);

    final directionStr = _isIncoming ? 'incoming' : 'outgoing';

    final rows = await (_db.select(_db.payments)
          ..where((p) => p.isDeleted.equals(false) & p.direction.equals(directionStr))
          ..orderBy([(p) => drift.OrderingTerm.desc(p.date)]))
        .get();

    final result = <_PaymentRow>[];
    for (final payment in rows) {
      String partyName = _isIncoming ? loc.customerDefault : loc.supplierDefault;
      if (_isIncoming && payment.customerId != null) {
        final c = await (_db.select(_db.customers)
              ..where((cu) => cu.id.equals(payment.customerId!)))
            .getSingleOrNull();
        if (c != null) partyName = c.name;
      } else if (!_isIncoming && payment.supplierId != null) {
        final s = await (_db.select(_db.suppliers)
              ..where((su) => su.id.equals(payment.supplierId!)))
            .getSingleOrNull();
        if (s != null) partyName = s.name;
      }
      result.add(_PaymentRow(payment: payment, partyName: partyName));
    }

    if (!mounted) return;
    setState(() {
      _payments = result;
      _loading = false;
    });
  }

  String _methodLabel(String method, AppLocalizations loc) {
    switch (method) {
      case 'cash':
        return loc.cash;
      case 'bank':
        return loc.bank;
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(_isIncoming ? loc.customerPayments : loc.supplierPayments),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _payments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isIncoming ? Icons.payments_outlined : Icons.money_off_csred_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isIncoming ? loc.noIncomingPayments : loc.noOutgoingPayments,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final row = _payments[index];
                        final p = row.payment;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _isIncoming
                                  ? const Color(0xFF43A047).withValues(alpha: 0.1)
                                  : const Color(0xFFE53935).withValues(alpha: 0.1),
                              child: Icon(
                                _isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                                color: _isIncoming ? const Color(0xFF43A047) : const Color(0xFFE53935),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              row.partyName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDate(p.date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _methodLabel(p.paymentMethod, loc),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(p.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isIncoming ? const Color(0xFF43A047) : const Color(0xFFE53935),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${p.paymentNumber}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      );
  }
}

class _PaymentRow {
  final PaymentData payment;
  final String partyName;
  const _PaymentRow({required this.payment, required this.partyName});
}

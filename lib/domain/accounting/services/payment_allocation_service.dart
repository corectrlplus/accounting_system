import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

@immutable
class AllocationResult {
  final String allocationId;
  final String paymentId;
  final String? saleId;
  final String? purchaseId;
  final int allocatedAmount;
  final int remainingPaymentAmount;
  final int remainingDocumentAmount;

  const AllocationResult({
    required this.allocationId,
    required this.paymentId,
    this.saleId,
    this.purchaseId,
    required this.allocatedAmount,
    required this.remainingPaymentAmount,
    required this.remainingDocumentAmount,
  });
}

@immutable
class PaymentAllocationService {
  final AppDatabase db;

  const PaymentAllocationService(this.db);

  Future<AllocationResult> allocatePayment({
    required String paymentId,
    String? saleId,
    String? purchaseId,
    required int amount,
    required String companyId,
    required String deviceId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Allocation amount must be positive, got $amount');
    }

    final payment = await (db.select(db.payments)
          ..where((p) => p.id.equals(paymentId) & p.companyId.equals(companyId)))
        .getSingleOrNull();

    if (payment == null) {
      throw StateError('Payment $paymentId not found');
    }

    if (payment.status != 'posted') {
      throw StateError('Payment $paymentId must be posted, got ${payment.status}');
    }

    if (saleId == null && purchaseId == null) {
      throw ArgumentError('Exactly one of saleId or purchaseId must be provided');
    }

    if (saleId != null && purchaseId != null) {
      throw ArgumentError('Only one of saleId or purchaseId may be provided, not both');
    }

    if (payment.direction == 'incoming' && purchaseId != null) {
      throw ArgumentError('Incoming payment cannot be allocated to a purchase');
    }

    if (payment.direction == 'outgoing' && saleId != null) {
      throw ArgumentError('Outgoing payment cannot be allocated to a sale');
    }

    final remainingPayment = await getUnallocatedAmount(paymentId);
    if (amount > remainingPayment) {
      throw ArgumentError(
        'Allocation amount $amount exceeds remaining payment amount $remainingPayment',
      );
    }

    final remainingDoc = await getDocumentOutstanding(saleId, purchaseId);
    if (amount > remainingDoc) {
      throw ArgumentError(
        'Allocation amount $amount exceeds remaining document amount $remainingDoc',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final allocationId = _generateId();

    await db.into(db.paymentAllocations).insert(
          PaymentAllocationsCompanion.insert(
            id: allocationId,
            companyId: companyId,
            paymentId: paymentId,
            saleId: Value<String?>(saleId),
            purchaseId: Value<String?>(purchaseId),
            allocatedAmount: amount,
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
        );

    return AllocationResult(
      allocationId: allocationId,
      paymentId: paymentId,
      saleId: saleId,
      purchaseId: purchaseId,
      allocatedAmount: amount,
      remainingPaymentAmount: remainingPayment - amount,
      remainingDocumentAmount: remainingDoc - amount,
    );
  }

  Future<List<AllocationResult>> allocatePaymentFully({
    required String paymentId,
    required String companyId,
    required String deviceId,
  }) async {
    final payment = await (db.select(db.payments)
          ..where((p) => p.id.equals(paymentId) & p.companyId.equals(companyId)))
        .getSingleOrNull();

    if (payment == null) {
      throw StateError('Payment $paymentId not found');
    }

    if (payment.status != 'posted') {
      throw StateError('Payment $paymentId must be posted, got ${payment.status}');
    }

    final results = <AllocationResult>[];
    var remaining = await getUnallocatedAmount(paymentId);

    if (remaining <= 0) return results;

    if (payment.direction == 'incoming') {
      final sales = await (db.select(db.sales)
            ..where((s) =>
                s.customerId.equals(payment.customerId!) &
                s.companyId.equals(companyId) &
                s.status.equals('posted'))
            ..orderBy([(s) => OrderingTerm.asc(s.date)]))
          .get();

      for (final sale in sales) {
        if (remaining <= 0) break;

        final outstanding = await getDocumentOutstanding(sale.id, null);
        if (outstanding <= 0) continue;

        final allocAmount = remaining < outstanding ? remaining : outstanding;

        final result = await allocatePayment(
          paymentId: paymentId,
          saleId: sale.id,
          amount: allocAmount,
          companyId: companyId,
          deviceId: deviceId,
        );
        results.add(result);
        remaining = result.remainingPaymentAmount;
      }
    } else {
      final purchases = await (db.select(db.purchases)
            ..where((p) =>
                p.supplierId.equals(payment.supplierId!) &
                p.companyId.equals(companyId) &
                p.status.equals('posted'))
            ..orderBy([(p) => OrderingTerm.asc(p.date)]))
          .get();

      for (final purchase in purchases) {
        if (remaining <= 0) break;

        final outstanding = await getDocumentOutstanding(null, purchase.id);
        if (outstanding <= 0) continue;

        final allocAmount = remaining < outstanding ? remaining : outstanding;

        final result = await allocatePayment(
          paymentId: paymentId,
          purchaseId: purchase.id,
          amount: allocAmount,
          companyId: companyId,
          deviceId: deviceId,
        );
        results.add(result);
        remaining = result.remainingPaymentAmount;
      }
    }

    return results;
  }

  Future<int> getUnallocatedAmount(String paymentId) async {
    final payment = await (db.select(db.payments)
          ..where((p) => p.id.equals(paymentId)))
        .getSingleOrNull();

    if (payment == null) return 0;

    final allocations = await (db.select(db.paymentAllocations)
          ..where((a) => a.paymentId.equals(paymentId)))
        .get();

    final totalAllocated = allocations.fold<int>(
      0,
      (sum, a) => sum + a.allocatedAmount,
    );

    return payment.amount - totalAllocated;
  }

  Future<int> getDocumentOutstanding(String? saleId, String? purchaseId) async {
    if (saleId != null) {
      final sale = await (db.select(db.sales)
            ..where((s) => s.id.equals(saleId)))
          .getSingleOrNull();

      if (sale == null) return 0;

      final allocations = await (db.select(db.paymentAllocations)
            ..where((a) => a.saleId.equals(saleId)))
          .get();

      final totalAllocated = allocations.fold<int>(
        0,
        (sum, a) => sum + a.allocatedAmount,
      );

      return sale.totalAmount - totalAllocated;
    }

    if (purchaseId != null) {
      final purchase = await (db.select(db.purchases)
            ..where((p) => p.id.equals(purchaseId)))
          .getSingleOrNull();

      if (purchase == null) return 0;

      final allocations = await (db.select(db.paymentAllocations)
            ..where((a) => a.purchaseId.equals(purchaseId)))
          .get();

      final totalAllocated = allocations.fold<int>(
        0,
        (sum, a) => sum + a.allocatedAmount,
      );

      return purchase.totalAmount - totalAllocated;
    }

    return 0;
  }

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}

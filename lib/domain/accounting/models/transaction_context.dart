import 'package:meta/meta.dart';
import '../../../core/sync/idempotency_generator.dart';

/// Transaction Execution Context carrying tenancy, identity, and device metadata.
@immutable
class TransactionContext {
  final String companyId;
  final String userId;
  final String deviceId;
  final int timestampMs;

  const TransactionContext({
    required this.companyId,
    required this.userId,
    required this.deviceId,
    required this.timestampMs,
  });

  /// Factory creating context with current local time.
  factory TransactionContext.now({
    required String companyId,
    required String userId,
    required String deviceId,
  }) {
    return TransactionContext(
      companyId: companyId,
      userId: userId,
      deviceId: deviceId,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionContext &&
          runtimeType == other.runtimeType &&
          companyId == other.companyId &&
          userId == other.userId &&
          deviceId == other.deviceId &&
          timestampMs == other.timestampMs;

  @override
  int get hashCode =>
      companyId.hashCode ^ userId.hashCode ^ deviceId.hashCode ^ timestampMs.hashCode;
}

/// Idempotency Tracking Context wrapper.
@immutable
class IdempotencyContext {
  final String key;

  const IdempotencyContext(this.key);

  /// Generate deterministic idempotency context using core IdempotencyGenerator.
  factory IdempotencyContext.generate({
    required String companyId,
    required String sourceType,
    required String sourceId,
    String? deviceId,
  }) {
    final key = IdempotencyGenerator.generateKey(
      companyId: companyId,
      sourceType: sourceType,
      sourceId: sourceId,
      deviceId: deviceId,
    );
    return IdempotencyContext(key);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdempotencyContext &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

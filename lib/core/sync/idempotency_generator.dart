import 'package:uuid/uuid.dart';

/// Helper for client-side UUID v4 generation and deterministic financial idempotency keys.
class IdempotencyGenerator {
  static const Uuid _uuid = Uuid();

  /// Generate a globally unique client-side UUID v4.
  static String generateUuid() {
    return _uuid.v4();
  }

  /// Generate a deterministic idempotency key for financial business operations.
  /// Format: {companyId}:{sourceType}:{sourceId} (or optional deviceId)
  ///
  /// CRITICAL REQUIREMENT:
  /// Timestamps MUST NOT be included in idempotency keys. Retrying the same financial
  /// business operation after a network timeout, socket failure, or application restart
  /// MUST produce the EXACT SAME key regardless of retry execution time.
  static String generateKey({
    required String companyId,
    required String sourceType,
    required String sourceId,
    String? deviceId,
  }) {
    if (companyId.trim().isEmpty) throw ArgumentError('companyId cannot be empty');
    if (sourceType.trim().isEmpty) throw ArgumentError('sourceType cannot be empty');
    if (sourceId.trim().isEmpty) throw ArgumentError('sourceId cannot be empty');

    final comp = companyId.trim();
    final type = sourceType.trim();
    final id = sourceId.trim();

    if (deviceId != null && deviceId.trim().isNotEmpty) {
      return '$comp:$type:$id:${deviceId.trim()}';
    }
    return '$comp:$type:$id';
  }

  /// Validate if a string is a valid UUID v4 format.
  static bool isValidUuid(String id) {
    try {
      return Uuid.isValidUUID(fromString: id);
    } catch (_) {
      return false;
    }
  }
}

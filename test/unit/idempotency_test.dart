import 'package:test/test.dart';
import '../../lib/core/sync/idempotency_generator.dart';

void main() {
  group('Idempotency & UUID Tests', () {
    test('1. Generates valid UUID v4', () {
      final uuid = IdempotencyGenerator.generateUuid();
      expect(IdempotencyGenerator.isValidUuid(uuid), isTrue);
    });

    test('2. Same business operation + same source identity yields SAME key', () {
      final key1 = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-123',
        deviceId: 'dev-001',
      );

      final key2 = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-123',
        deviceId: 'dev-001',
      );

      expect(key1, equals(key2));
      expect(key1, equals('comp_1:sale:sale-123:dev-001'));
    });

    test('3. Retrying after a different timestamp or delay does NOT create a new key', () {
      // Simulating Retry 1 at T = 0ms
      final keyInitial = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-999',
        deviceId: 'dev-001',
      );

      // Simulating Retry 2 after network timeout 5 seconds later
      final keyRetry1 = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-999',
        deviceId: 'dev-001',
      );

      // Simulating Retry 3 after app restart 1 day later
      final keyRetry2 = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-999',
        deviceId: 'dev-001',
      );

      expect(keyInitial, equals(keyRetry1));
      expect(keyInitial, equals(keyRetry2));
    });

    test('4. Genuinely different transaction produces a different key', () {
      final keySaleA = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-100',
        deviceId: 'dev-001',
      );

      final keySaleB = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-101',
        deviceId: 'dev-001',
      );

      expect(keySaleA, isNot(equals(keySaleB)));
    });

    test('5. Same source ID cannot collide across different transaction types', () {
      final keySale = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'doc-001',
        deviceId: 'dev-001',
      );

      final keyPurchase = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'purchase',
        sourceId: 'doc-001',
        deviceId: 'dev-001',
      );

      expect(keySale, isNot(equals(keyPurchase)));
      expect(keySale, equals('comp_1:sale:doc-001:dev-001'));
      expect(keyPurchase, equals('comp_1:purchase:doc-001:dev-001'));
    });

    test('6. Device information handled cleanly without breaking retry idempotency', () {
      final keyWithDev = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-555',
        deviceId: 'dev-001',
      );

      final keyWithoutDev = IdempotencyGenerator.generateKey(
        companyId: 'comp_1',
        sourceType: 'sale',
        sourceId: 'sale-555',
      );

      expect(keyWithDev, equals('comp_1:sale:sale-555:dev-001'));
      expect(keyWithoutDev, equals('comp_1:sale:sale-555'));
    });
  });
}

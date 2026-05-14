import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/services/random_pool_service.dart';

void main() {
  test('returns all ids once before exhaustion', () {
    final service = RandomPoolService(seed: 7);
    service.reset(['a', 'b', 'c']);

    final seen = {service.next()!, service.next()!, service.next()!};
    expect(seen.length, 3);

    // Pool is now exhausted — should return null
    expect(service.next(), isNull);
  });

  test('isExhausted is true when all ids have been seen', () {
    final service = RandomPoolService(seed: 7);
    service.reset(['a', 'b']);

    expect(service.isExhausted, isFalse);

    service.next();
    expect(service.isExhausted, isFalse);

    service.next();
    expect(service.isExhausted, isTrue);
  });

  test('isExhausted is false after reset', () {
    final service = RandomPoolService(seed: 7);
    service.reset(['a', 'b']);

    service.next();
    service.next();
    expect(service.isExhausted, isTrue);

    service.reset(['a', 'b']);
    expect(service.isExhausted, isFalse);
    expect(service.next(), isNotNull);
  });

  test('markConsumed prevents id from appearing in next', () {
    final service = RandomPoolService(seed: 7);
    service.reset(['a', 'b', 'c']);

    service.markConsumed('a');
    service.markConsumed('b');

    expect(service.next(), 'c');
    expect(service.next(), isNull);
    expect(service.isExhausted, isTrue);
  });

  test('peekNextIds exposes upcoming ids without consuming them', () {
    final service = RandomPoolService(seed: 7);
    service.reset(['a', 'b', 'c', 'd']);

    final peeked = service.peekNextIds(limit: 3);

    expect(peeked, hasLength(3));
    expect(peeked.toSet().length, 3);
    expect([service.next(), service.next(), service.next()], peeked);
  });

  test('isExhausted is false for empty pool', () {
    final service = RandomPoolService(seed: 7);
    service.reset([]);

    expect(service.isExhausted, isFalse);
    expect(service.next(), isNull);
  });
}

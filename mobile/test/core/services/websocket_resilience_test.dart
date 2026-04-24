import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/services/websocket_resilience.dart';

void main() {
  group('websocketReconnectDelay', () {
    test('starts fast for small network cuts', () {
      expect(websocketReconnectDelay(attempt: 0), const Duration(seconds: 1));
      expect(websocketReconnectDelay(attempt: 1), const Duration(seconds: 2));
      expect(websocketReconnectDelay(attempt: 2), const Duration(seconds: 3));
    });

    test('caps retries to avoid freezing for too long', () {
      expect(websocketReconnectDelay(attempt: 4), const Duration(seconds: 8));
      expect(websocketReconnectDelay(attempt: 6), const Duration(seconds: 21));
      expect(websocketReconnectDelay(attempt: 20), const Duration(seconds: 30));
    });
  });

  group('isWebSocketConnectionStale', () {
    test('stays healthy while ping traffic is recent', () {
      final now = DateTime(2026, 4, 23, 12, 0, 45);
      final lastActivityAt = DateTime(2026, 4, 23, 12, 0, 5);

      expect(
        isWebSocketConnectionStale(
          now: now,
          lastActivityAt: lastActivityAt,
        ),
        isFalse,
      );
    });

    test('forces recovery when socket stayed silent for too long', () {
      final now = DateTime(2026, 4, 23, 12, 1, 0);
      final lastActivityAt = DateTime(2026, 4, 23, 12, 0, 5);

      expect(
        isWebSocketConnectionStale(
          now: now,
          lastActivityAt: lastActivityAt,
        ),
        isTrue,
      );
    });
  });
}

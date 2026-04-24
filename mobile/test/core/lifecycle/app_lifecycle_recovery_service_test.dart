import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/lifecycle/app_lifecycle_recovery_service.dart';

void main() {
  group('AppLifecycleRecoveryService', () {
    test('runs resume handlers only after a paused -> resumed transition',
        () async {
      final service = AppLifecycleRecoveryService();
      final calls = <String>[];

      service.registerResumeHandler('tracking', () async {
        calls.add('tracking');
      });
      service.registerResumeHandler('home-client', () async {
        calls.add('home-client');
      });

      await service.onLifecycleStateChanged(AppLifecycleState.resumed);
      expect(calls, isEmpty);

      await service.onLifecycleStateChanged(AppLifecycleState.paused);
      await service.onLifecycleStateChanged(AppLifecycleState.resumed);

      expect(calls, ['tracking', 'home-client']);
    });

    test('stops calling a handler after it has been unregistered', () async {
      final service = AppLifecycleRecoveryService();
      final calls = <String>[];

      final unregister = service.registerResumeHandler('tracking', () async {
        calls.add('tracking');
      });

      unregister();

      await service.onLifecycleStateChanged(AppLifecycleState.paused);
      await service.onLifecycleStateChanged(AppLifecycleState.resumed);

      expect(calls, isEmpty);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/screens/driver_home_screen.dart';

void main() {
  group('buildDriverGpsStatusState', () {
    test('GPS actif returns green active status', () {
      final state = buildDriverGpsStatusState(
        isOnline: true,
        hasPositionFix: true,
        lastPositionSentAt: DateTime.now(),
        hasLocationProblem: false,
      );

      expect(state.level, DriverGpsStatusLevel.active);
      expect(state.title, 'GPS actif');
    });

    test('stale GPS over 5 minutes returns orange inactive status', () {
      final state = buildDriverGpsStatusState(
        isOnline: true,
        hasPositionFix: true,
        lastPositionSentAt: DateTime.now().subtract(const Duration(minutes: 6)),
        hasLocationProblem: false,
      );

      expect(state.level, DriverGpsStatusLevel.inactive);
      expect(state.title, contains('GPS inactif'));
    });

    test('missing position while online returns red missing status', () {
      final state = buildDriverGpsStatusState(
        isOnline: true,
        hasPositionFix: false,
        lastPositionSentAt: null,
        hasLocationProblem: true,
      );

      expect(state.level, DriverGpsStatusLevel.missing);
      expect(state.title, contains('Position introuvable'));
    });
  });

  testWidgets('Activer le GPS button triggers settings action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsStatusCard(
            state: const DriverGpsStatusState(
              level: DriverGpsStatusLevel.inactive,
              title: 'GPS inactif - vous ne recevez pas de demandes',
              showAction: true,
            ),
            onOpenGpsSettings: () async {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Activer le GPS'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}

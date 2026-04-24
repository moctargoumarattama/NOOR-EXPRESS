import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart';

void main() {
  testWidgets('TrackingRecoveryBanner shows manual refresh in degraded states',
      (
    tester,
  ) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackingRecoveryBanner(
            connectionState: TrackingConnectionState.reconnecting,
            message: 'Reconnexion en cours...',
            onRefresh: () => refreshes++,
          ),
        ),
      ),
    );

    expect(find.text('Rafraichir l etat'), findsOneWidget);
    await tester.tap(find.text('Rafraichir l etat'));
    expect(refreshes, 1);
  });
}

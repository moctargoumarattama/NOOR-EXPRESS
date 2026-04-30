import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart';

void main() {
  testWidgets('TrackingTopBar shows remaining distance and reliable ETA',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: TrackingTopBar(
            connectionState: TrackingConnectionState.connected,
            etaMinutes: 8,
            distanceRemainingKm: 4.2,
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.text('4.2 km'), findsOneWidget);
    expect(find.text('Dans 8 min'), findsOneWidget);
    expect(find.text('En direct'), findsOneWidget);
  });

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

    expect(find.text('Mettre a jour'), findsOneWidget);
    await tester.tap(find.text('Mettre a jour'));
    expect(refreshes, 1);
  });
}

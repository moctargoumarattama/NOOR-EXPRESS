import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noor_express_mobile/features/map/models/route_result.dart';
import 'package:noor_express_mobile/features/map/widgets/eta_overlay.dart';

void main() {
  testWidgets('EtaOverlay does not present fallback routes as reliable ETA',
      (tester) async {
    final route = RouteResult.fallback(
      const LatLng(13.5, 2.1),
      const LatLng(13.48, 2.17),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EtaOverlay(route: route),
        ),
      ),
    );

    expect(find.textContaining('min'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/route_summary_card.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/features/map/models/route_result.dart';

void main() {
  testWidgets(
    'searching pending shows route summary, proposed price and cancel action',
    (tester) async {
      final controller = TextEditingController();
      var openedOffers = false;
      var cancelled = false;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBottomSheet(
              pickup: null,
              dropoff: null,
              priceController: controller,
              isCreating: false,
              isEstimatingPrice: false,
              activeRide: _ride(status: 'pending'),
              activeRideRoute: _route,
              nearbyDriversCount: 2,
              onPickupTap: _noop,
              onDropoffTap: _noop,
              onClearPickup: _noop,
              onClearDropoff: _noop,
              onSubmit: _noop,
              onOpenActiveRide: () => openedOffers = true,
              onCancelActiveRide: () => cancelled = true,
              recentDepartureLabels: const ['Plateau'],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('On cherche un chauffeur'), findsOneWidget);
      expect(find.byType(RouteSummaryCard), findsOneWidget);
      expect(find.text('Grand Marche'), findsOneWidget);
      expect(find.text('Aeroport'), findsOneWidget);
      expect(find.text('6.4 km'), findsOneWidget);
      expect(find.text('18 min'), findsOneWidget);
      expect(find.text('Prix propose'), findsOneWidget);
      expect(find.text('2500'), findsOneWidget);
      expect(
        find.text('2 chauffeurs proches consultent votre demande.'),
        findsOneWidget,
      );
      expect(find.text('Voir les offres'), findsNothing);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Annuler la demande'));
      await tester.pump();

      expect(cancelled, isTrue);
      expect(openedOffers, isFalse);
    },
  );

  testWidgets('searching offered shows Voir les offres conditionally',
      (tester) async {
    final controller = TextEditingController();
    var openedOffers = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: null,
            dropoff: null,
            priceController: controller,
            isCreating: false,
            isEstimatingPrice: false,
            activeRide: _ride(status: 'offered'),
            activeRideRoute: _route,
            onPickupTap: _noop,
            onDropoffTap: _noop,
            onClearPickup: _noop,
            onClearDropoff: _noop,
            onSubmit: _noop,
            onOpenActiveRide: () => openedOffers = true,
            onCancelActiveRide: _noop,
            recentDepartureLabels: const ['Plateau'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('On cherche un chauffeur'), findsOneWidget);
    expect(find.text('Voir les offres'), findsOneWidget);
    expect(find.text('Annuler la demande'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Voir les offres'));
    await tester.pump();

    expect(openedOffers, isTrue);
  });
}

ClientRide _ride({required String status}) {
  return ClientRide(
    id: 42,
    pickupLocation: 'Grand Marche',
    dropoffLocation: 'Aeroport',
    status: status,
    estimatedPrice: 2500,
    createdAt: DateTime(2026, 4, 24, 10),
  );
}

const _route = RouteResult(
  polylinePoints: [LatLng(13.5, 2.1), LatLng(13.48, 2.17)],
  distanceKm: 6.4,
  durationMinutes: 18,
);

void _noop() {}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noor_express_mobile/features/address_search/domain/entities/address_result.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/price_selector.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/features/map/models/route_result.dart';

void main() {
  testWidgets(
    'SearchBottomSheet shows route preview with Course, route metrics, and price controls',
    (tester) async {
      final controller = TextEditingController(text: '2500');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBottomSheet(
              pickup: _pickup,
              dropoff: _dropoff,
              route: const RouteResult(
                polylinePoints: [LatLng(13.5, 2.1), LatLng(13.48, 2.17)],
                distanceKm: 6.4,
                durationMinutes: 18,
              ),
              priceController: controller,
              isCreating: false,
              isEstimatingPrice: false,
              estimate: const PriceEstimate(
                estimatedPrice: 2500,
                distanceKm: 6.4,
              ),
              activeRide: null,
              onPickupTap: _noop,
              onDropoffTap: _noop,
              onClearPickup: _noop,
              onClearDropoff: _noop,
              onSubmit: _noop,
              onOpenActiveRide: _noop,
              recentDepartureLabels: const ['Plateau', 'Agdal', 'Ocean'],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Course'), findsOneWidget);
      expect(find.text('6.4 km'), findsOneWidget);
      expect(find.text('18 min'), findsOneWidget);
      expect(find.text('Prix recommande'), findsOneWidget);
      expect(find.byType(PriceSelector), findsOneWidget);
      expect(find.text('Trouver un chauffeur'), findsOneWidget);
    },
  );

  testWidgets('SearchBottomSheet keeps unreliable prices out of route preview',
      (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: _pickup,
            dropoff: _dropoff,
            route: const RouteResult(
              polylinePoints: [LatLng(13.5, 2.1), LatLng(13.48, 2.17)],
              distanceKm: 0,
              durationMinutes: 0,
            ),
            priceController: controller,
            isCreating: false,
            isEstimatingPrice: false,
            estimate: const PriceEstimate(
              estimatedPrice: 0,
              distanceKm: 0,
            ),
            activeRide: null,
            onPickupTap: _noop,
            onDropoffTap: _noop,
            onClearPickup: _noop,
            onClearDropoff: _noop,
            onSubmit: _noop,
            onOpenActiveRide: _noop,
            recentDepartureLabels: const ['Plateau', 'Agdal', 'Ocean'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Prix recommande'), findsNothing);
    expect(find.textContaining('pas encore fiables'), findsOneWidget);
  });
}

const _pickup = AddressResult(
  name: 'Grand Marche',
  displayName: 'Grand Marche',
  latitude: 13.5,
  longitude: 2.1,
  type: 'zone',
);

const _dropoff = AddressResult(
  name: 'Aeroport',
  displayName: 'Aeroport',
  latitude: 13.48,
  longitude: 2.17,
  type: 'zone',
);

void _noop() {}

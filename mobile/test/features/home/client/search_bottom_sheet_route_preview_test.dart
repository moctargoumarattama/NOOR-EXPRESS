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
    'SearchBottomSheet shows a compact route preview with visible action',
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

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.initialChildSize, lessThanOrEqualTo(0.55));
      expect(sheet.maxChildSize, lessThanOrEqualTo(0.60));
      expect(find.text('Grand Marche \u2192 Aeroport'), findsOneWidget);
      expect(find.text('Grand Marche'), findsNothing);
      expect(find.text('Aeroport'), findsNothing);
      expect(find.text('6.4 km \u2022 18 min'), findsOneWidget);
      expect(find.text('Prix recommande : 2500 FCFA'), findsOneWidget);
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

    expect(find.text('Estimation indisponible'), findsOneWidget);
    expect(find.textContaining('pas encore fiables'), findsNothing);
    expect(find.text('--'), findsNothing);
    expect(find.textContaining('Prix recommande'), findsNothing);
  });

  testWidgets('SearchBottomSheet treats fallback routes as unavailable',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: _pickup,
            dropoff: _dropoff,
            route: RouteResult.fallback(
              const LatLng(13.5, 2.1),
              const LatLng(13.48, 2.17),
            ),
            priceController: controller,
            isCreating: false,
            isEstimatingPrice: false,
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

    expect(find.text('Estimation indisponible'), findsOneWidget);
    expect(find.textContaining('Prix recommande'), findsNothing);
    expect(find.textContaining('indisponibles'), findsNothing);
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noor_express_mobile/features/address_search/domain/entities/address_result.dart';
import 'package:noor_express_mobile/core/location/location_quality.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/price_selector.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/features/map/models/route_result.dart';

void main() {
  testWidgets(
    'SearchBottomSheet shows a compact route preview with visible action',
    (tester) async {
      await _setMobileViewport(tester);
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
              pickupLocationQuality: LocationQuality.confirmed,
              canSubmitRideRequest: true,
              estimate: const PriceEstimate(
                estimatedPrice: 2500,
                distanceKm: 6.4,
                durationMin: 18,
                minPrice: 2200,
                maxPrice: 2800,
                availableDriversCount: 2,
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
      expect(sheet.initialChildSize, 0.88);
      expect(sheet.maxChildSize, 0.95);
      expect(find.text('Grand Marche \u2192 Aeroport'), findsOneWidget);
      expect(find.text('Grand Marche'), findsNothing);
      expect(find.text('Aeroport'), findsNothing);
      expect(find.text('6.4 km'), findsOneWidget);
      expect(find.text('18 min'), findsOneWidget);
      expect(find.text('Estimation : 2200 - 2800 FCFA'), findsOneWidget);
      expect(
          find.text('2 chauffeurs disponibles pres de vous'), findsOneWidget);
      expect(find.byType(PriceSelector), findsOneWidget);
      expect(find.text('+100').hitTestable(), findsOneWidget);
      expect(find.text('Trouver un chauffeur'), findsOneWidget);
    },
  );

  testWidgets(
    'SearchBottomSheet shows quick price adjustments without scrolling',
    (tester) async {
      await _setMobileViewport(tester);
      final controller = TextEditingController(text: '2400');
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
              pickupLocationQuality: LocationQuality.confirmed,
              canSubmitRideRequest: true,
              estimate: const PriceEstimate(
                estimatedPrice: 2400,
                distanceKm: 6.4,
                durationMin: 18,
                minPrice: 2200,
                maxPrice: 2800,
                availableDriversCount: 2,
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

      expect(find.text('-200').hitTestable(), findsOneWidget);
      expect(find.text('-100').hitTestable(), findsOneWidget);
      expect(find.text('+100').hitTestable(), findsOneWidget);
      expect(find.text('+200').hitTestable(), findsOneWidget);

      await tester.tap(find.text('+200'));
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, '2600');
    },
  );

  testWidgets('SearchBottomSheet keeps unreliable prices out of route preview',
      (
    tester,
  ) async {
    await _setMobileViewport(tester);
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
            pickupLocationQuality: LocationQuality.confirmed,
            canSubmitRideRequest: true,
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
    await _setMobileViewport(tester);
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
            pickupLocationQuality: LocationQuality.confirmed,
            canSubmitRideRequest: true,
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

  testWidgets(
      'SearchBottomSheet exposes add-to-favorites action on route preview',
      (tester) async {
    await _setMobileViewport(tester);
    final controller = TextEditingController(text: '2500');
    addTearDown(controller.dispose);
    AddressResult? addedDropoff;

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
            pickupLocationQuality: LocationQuality.confirmed,
            canSubmitRideRequest: true,
            activeRide: null,
            onPickupTap: _noop,
            onDropoffTap: _noop,
            onClearPickup: _noop,
            onClearDropoff: _noop,
            onSubmit: _noop,
            onOpenActiveRide: _noop,
            onAddToFavorites: (dropoff) async => addedDropoff = dropoff,
            recentDepartureLabels: const ['Plateau', 'Agdal', 'Ocean'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ajouter aux favoris'), findsOneWidget);
    await tester.ensureVisible(find.text('Ajouter aux favoris'));
    await tester.tap(find.text('Ajouter aux favoris'));
    await tester.pump();

    expect(addedDropoff?.name, _dropoff.name);
  });

  testWidgets(
    'SearchBottomSheet disables submit and shows warning when pickup is unknown',
    (tester) async {
      await _setMobileViewport(tester);
      final controller = TextEditingController(text: '2500');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBottomSheet(
              pickup: null,
              dropoff: _dropoff,
              route: const RouteResult(
                polylinePoints: [LatLng(13.5, 2.1), LatLng(13.48, 2.17)],
                distanceKm: 6.4,
                durationMinutes: 18,
              ),
              priceController: controller,
              isCreating: false,
              isEstimatingPrice: false,
              pickupLocationQuality: LocationQuality.unknown,
              canSubmitRideRequest: false,
              submitDisabledReason:
                  'Position non disponible. Recherchez votre adresse de depart manuellement.',
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

      expect(
        find.text(
          'Position non disponible. Recherchez votre adresse de depart manuellement.',
        ),
        findsOneWidget,
      );

      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Trouver un chauffeur'),
      );
      expect(submitButton.onPressed, isNull);
    },
  );
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

Future<void> _setMobileViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

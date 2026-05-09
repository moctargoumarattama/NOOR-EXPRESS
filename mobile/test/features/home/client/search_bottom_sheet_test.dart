import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noor_express_mobile/core/location/location_quality.dart';
import 'package:noor_express_mobile/features/address_search/domain/entities/address_result.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/home_idle_sheet.dart';
import 'package:noor_express_mobile/features/map/models/route_result.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets(
      'SearchBottomSheet keeps route preview compact while creating a ride', (
    tester,
  ) async {
    await _setMobileViewport(tester);
    final controller = TextEditingController(text: '2500');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: const AddressResult(
              name: 'Grand Marche',
              displayName: 'Grand Marche',
              latitude: 13.5,
              longitude: 2.1,
              type: 'zone',
            ),
            dropoff: const AddressResult(
              name: 'Aeroport',
              displayName: 'Aeroport',
              latitude: 13.48,
              longitude: 2.17,
              type: 'zone',
            ),
            priceController: controller,
            isCreating: true,
            isEstimatingPrice: true,
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

    expect(find.text('Estimation en cours...'), findsWidgets);
    expect(find.byType(AppInlineFeedback), findsNothing);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets(
      'SearchBottomSheet keeps the booking launcher and recent departures when there is no real active ride',
      (tester) async {
    await _setMobileViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: null,
            dropoff: null,
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

    expect(find.text('Ou allez-vous ?'), findsOneWidget);
    expect(find.text('Voir le trajet'), findsNothing);
    expect(find.text('Plateau'), findsOneWidget);
    expect(find.text('Agdal'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
  });

  testWidgets(
      'SearchBottomSheet recent addresses trigger direct selection when address data is available',
      (tester) async {
    await _setMobileViewport(tester, size: const Size(390, 1400));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    AddressResult? selectedRecent;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: null,
            dropoff: null,
            recentAddresses: const [
              AddressResult(
                name: 'Hopital National',
                displayName: 'Hopital National',
                latitude: 13.51,
                longitude: 2.14,
                type: 'recent',
              ),
            ],
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
            onRecentTap: (address) => selectedRecent = address,
            recentDepartureLabels: const ['Plateau', 'Agdal', 'Ocean'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final recentAction = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Hopital National'),
        matching: find.byType(InkWell),
      ).first,
    );
    recentAction.onTap?.call();
    await tester.pump();

    expect(selectedRecent?.name, 'Hopital National');
  });

  testWidgets(
      'SearchBottomSheet does not force tracking for accepted rides on the home search sheet',
      (tester) async {
    await _setMobileViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: null,
            dropoff: null,
            priceController: controller,
            isCreating: false,
            isEstimatingPrice: false,
            pickupLocationQuality: LocationQuality.confirmed,
            canSubmitRideRequest: true,
            activeRide: ClientRide(
              id: 18,
              pickupLocation: 'Plateau',
              dropoffLocation: 'Hay Riad',
              status: 'accepted',
              estimatedPrice: 3500,
              createdAt: DateTime(2026, 4, 24, 10),
            ),
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

    expect(find.text('Ou allez-vous ?'), findsOneWidget);
    expect(find.text('Voir le trajet'), findsNothing);
  });

  testWidgets(
      'favorite shortcut opens route preview directly with a prefilled estimate',
      (tester) async {
    await _setMobileViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _PassengerQuickRequestHarness(
            startWithFavorites: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Maison'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeIdleSheet), findsNothing);
    expect(find.text('Recherche destination'), findsNothing);
    expect(find.text('Trouver un chauffeur'), findsOneWidget);
    expect(find.text('Estimation : 2200 - 2800 FCFA'), findsOneWidget);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '2400');
  });

  testWidgets(
      'recent shortcut opens route preview directly with a prefilled estimate',
      (tester) async {
    await _setMobileViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _PassengerQuickRequestHarness(
            startWithRecents: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Hopital National'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeIdleSheet), findsNothing);
    expect(find.text('Recherche destination'), findsNothing);
    expect(find.text('Grand Marche → Hopital National'), findsOneWidget);
    expect(find.text('Trouver un chauffeur'), findsOneWidget);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '2400');
  });

  testWidgets('passenger can send a ride request in four taps maximum', (
    tester,
  ) async {
    await _setMobileViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _PassengerQuickRequestHarness(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Ou allez-vous ?'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir Aeroport'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+100'));
    await tester.pump();

    await tester.tap(find.text('Trouver un chauffeur'));
    await tester.pumpAndSettle();

    expect(find.text('Demande envoyee'), findsOneWidget);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '2500');
  });
}

void _noop() {}

enum _PassengerQuickRequestStep { idle, destinationSearch, routePreview, sent }

class _PassengerQuickRequestHarness extends StatefulWidget {
  const _PassengerQuickRequestHarness({
    this.startWithFavorites = false,
    this.startWithRecents = false,
  });

  final bool startWithFavorites;
  final bool startWithRecents;

  @override
  State<_PassengerQuickRequestHarness> createState() =>
      _PassengerQuickRequestHarnessState();
}

class _PassengerQuickRequestHarnessState
    extends State<_PassengerQuickRequestHarness> {
  static const _pickup = AddressResult(
    name: 'Grand Marche',
    displayName: 'Grand Marche',
    latitude: 13.5,
    longitude: 2.1,
    type: 'zone',
  );
  static const _dropoff = AddressResult(
    name: 'Aeroport',
    displayName: 'Aeroport',
    latitude: 13.48,
    longitude: 2.17,
    type: 'zone',
  );
  static const _favorite = AddressResult(
    name: 'Maison',
    displayName: 'Maison',
    latitude: 13.52,
    longitude: 2.12,
    type: 'saved',
  );
  static const _recent = AddressResult(
    name: 'Hopital National',
    displayName: 'Hopital National',
    latitude: 13.51,
    longitude: 2.14,
    type: 'recent',
  );
  static const _route = RouteResult(
    polylinePoints: [LatLng(13.5, 2.1), LatLng(13.48, 2.17)],
    distanceKm: 6.4,
    durationMinutes: 18,
  );
  static const _estimate = PriceEstimate(
    estimatedPrice: 2400,
    distanceKm: 6.4,
    durationMin: 18,
    minPrice: 2200,
    maxPrice: 2800,
    availableDriversCount: 2,
  );

  final _priceController = TextEditingController();
  _PassengerQuickRequestStep _step = _PassengerQuickRequestStep.idle;
  AddressResult? _selectedDropoff;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _PassengerQuickRequestStep.idle:
        return HomeIdleSheet(
          favorites: widget.startWithFavorites ? const [_favorite] : const [],
          recents: widget.startWithRecents ? const [_recent] : const [],
          onSearchTap: _openSearch,
          onFavoriteTap: _showPreview,
          onRecentTap: _showPreview,
        );
      case _PassengerQuickRequestStep.destinationSearch:
        return Center(
          child: FilledButton(
            onPressed: () => _showPreview(_dropoff),
            child: const Text('Choisir Aeroport'),
          ),
        );
      case _PassengerQuickRequestStep.routePreview:
      case _PassengerQuickRequestStep.sent:
        return Stack(
          children: [
            SearchBottomSheet(
              pickup: _pickup,
              dropoff: _selectedDropoff ?? _dropoff,
              route: _route,
              priceController: _priceController,
              isCreating: false,
              isEstimatingPrice: false,
              pickupLocationQuality: LocationQuality.confirmed,
              canSubmitRideRequest: true,
              estimate: _estimate,
              activeRide: null,
              onPickupTap: _noop,
              onDropoffTap: _noop,
              onClearPickup: _noop,
              onClearDropoff: _noop,
              onSubmit: _submitRide,
              onOpenActiveRide: _noop,
              recentDepartureLabels: const ['Plateau', 'Agdal', 'Ocean'],
            ),
            if (_step == _PassengerQuickRequestStep.sent)
              const Positioned(
                top: 24,
                left: 24,
                child: Material(
                  child: Text('Demande envoyee'),
                ),
              ),
          ],
        );
    }
  }

  void _openSearch() {
    setState(() => _step = _PassengerQuickRequestStep.destinationSearch);
  }

  void _showPreview([AddressResult? selectedDropoff]) {
    _priceController.text = _estimate.estimatedPrice.round().toString();
    setState(() {
      _selectedDropoff = selectedDropoff ?? _dropoff;
      _step = _PassengerQuickRequestStep.routePreview;
    });
  }

  void _submitRide() {
    setState(() => _step = _PassengerQuickRequestStep.sent);
  }
}

Future<void> _setMobileViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

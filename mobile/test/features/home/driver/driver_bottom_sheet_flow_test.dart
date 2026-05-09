import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_ride.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/widgets/driver_bottom_sheet.dart';

void main() {
  testWidgets(
      'rideReceived shows 3 quick prices, fallback custom link and timer',
      (tester) async {
    await _pumpSheet(
      tester,
      pendingRide: _ride(
        pickup: 'Ma position actuelle',
        dropoff: 'Plateau',
        estimatedPrice: 2500,
        distanceToPickupKm: 1.2,
      ),
      flowStage: DriverRideSheetStage.rideReceived,
    );

    expect(find.text('Une course vous attend'), findsOneWidget);
    expect(find.text('Point de prise en charge'), findsOneWidget);
    expect(find.text('Ma position actuelle'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Plateau'), findsOneWidget);
    expect(find.text('Accepter tel quel'), findsOneWidget);
    expect(find.text('+200'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('Autre prix →'), findsOneWidget);
    expect(find.text('2500 FCFA'), findsWidgets);
    expect(find.text('45 s'), findsOneWidget);
  });

  testWidgets('tap quick +200 sends offer without custom screen',
      (tester) async {
    double? submittedPrice;

    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 2500),
      flowStage: DriverRideSheetStage.rideReceived,
      onQuickOffer: (price) async {
        submittedPrice = price;
        return false;
      },
    );

    await tester.ensureVisible(find.text('+200'));
    await tester.tap(find.text('+200'));
    await tester.pump();

    expect(submittedPrice, 2700);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('quick offer success shows feedback then closes', (tester) async {
    bool closedAfterSuccess = false;

    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 2500),
      flowStage: DriverRideSheetStage.rideReceived,
      onQuickOffer: (_) async => true,
      onQuickOfferSuccess: (_) {
        closedAfterSuccess = true;
      },
    );

    await tester.ensureVisible(find.text('Accepter tel quel'));
    await tester.tap(find.text('Accepter tel quel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('Offre envoyee ✓'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(closedAfterSuccess, isTrue);
  });

  testWidgets('timer expiration triggers auto-dismiss callback',
      (tester) async {
    var timeoutCalled = false;

    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 2400),
      flowStage: DriverRideSheetStage.rideReceived,
      onRideRequestTimedOut: () {
        timeoutCalled = true;
      },
    );

    await tester.pump(const Duration(seconds: 46));
    await tester.pump(const Duration(milliseconds: 300));

    expect(timeoutCalled, isTrue);
  });

  testWidgets('custom price fallback action remains available', (tester) async {
    var customTapped = false;

    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 2600),
      flowStage: DriverRideSheetStage.rideReceived,
      onProposePrice: () {
        customTapped = true;
      },
    );

    await tester.ensureVisible(find.text('Autre prix →'));
    await tester.tap(find.text('Autre prix →'));
    await tester.pump();

    expect(customTapped, isTrue);
  });

  testWidgets('priceProposal prefills driver price from valid client price',
      (tester) async {
    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 2500),
      flowStage: DriverRideSheetStage.priceProposal,
    );

    expect(find.text('Votre proposition'), findsOneWidget);
    expect(find.text('Prix client'), findsOneWidget);
    expect(find.text('2500 FCFA'), findsOneWidget);
    expect(find.text('Envoyer ma proposition'), findsOneWidget);
    expect(find.text('Pas maintenant'), findsOneWidget);

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '2500');
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  DriverRide? pendingRide,
  DriverRideSheetStage flowStage = DriverRideSheetStage.idle,
  double? submittedOfferPrice,
  VoidCallback? onProposePrice,
  VoidCallback? onRideRequestTimedOut,
  ValueChanged<double>? onQuickOfferSuccess,
  Future<bool> Function(double price)? onQuickOffer,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 820,
          child: Stack(
            children: [
              DriverBottomSheet(
                driverStatus: 'online',
                isBusy: false,
                todayRides: 0,
                todayEarnings: 0,
                activeRide: null,
                pendingRide: pendingRide,
                flowStage: flowStage,
                submittedOfferPrice: submittedOfferPrice,
                onStart: _noop,
                onStop: _noop,
                onOpenTracking: _noop,
                onProposePrice: onProposePrice ?? _noop,
                onIgnoreRide: _noop,
                onQuickOffer: onQuickOffer ?? _quickOfferNoop,
                onQuickOfferSuccess: onQuickOfferSuccess,
                onRideRequestTimedOut: onRideRequestTimedOut,
                onSubmitOffer: (_) {},
                onBackToRideReceived: _noop,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

DriverRide _ride({
  String pickup = 'Grand Marche',
  String dropoff = 'Aeroport',
  double estimatedPrice = 2500,
  double? distanceToPickupKm,
}) {
  return DriverRide(
    id: 42,
    pickupLocation: pickup,
    dropoffLocation: dropoff,
    status: 'pending',
    estimatedPrice: estimatedPrice,
    distanceToPickupKm: distanceToPickupKm,
    createdAt: DateTime(2026, 4, 24, 10),
  );
}

Future<bool> _quickOfferNoop(double _) async => false;

void _noop() {}

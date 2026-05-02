import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_ride.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/widgets/driver_bottom_sheet.dart';

void main() {
  testWidgets('rideReceived shows clear pickup, destination and client price', (
    tester,
  ) async {
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
    expect(find.text('Prix client'), findsOneWidget);
    expect(find.text('2500 FCFA'), findsOneWidget);
    expect(find.text('A 1.2 km de vous'), findsOneWidget);
    expect(find.text('Proposer un prix'), findsOneWidget);
    expect(find.text('Ignorer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('priceProposal prefills driver price from valid client price', (
    tester,
  ) async {
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

  testWidgets('priceProposal disables sending when client price is invalid', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 0),
      flowStage: DriverRideSheetStage.priceProposal,
    );

    expect(find.text('Prix indisponible'), findsWidgets);
    expect(find.text('0 FCFA'), findsNothing);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Envoyer ma proposition'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('priceProposal treats absurd prices as unavailable', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      pendingRide: _ride(estimatedPrice: 9999999),
      flowStage: DriverRideSheetStage.priceProposal,
    );

    expect(find.text('Prix indisponible'), findsWidgets);
    expect(find.text('9999999 FCFA'), findsNothing);
  });

  testWidgets('driver flow moves rideReceived to priceProposal to offerSent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 820,
            child: Stack(
              children: [
                _DriverFlowHarness(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Une course vous attend'), findsOneWidget);

    await tester.tap(find.text('Proposer un prix'));
    await tester.pumpAndSettle();
    expect(find.text('Votre proposition'), findsOneWidget);

    await tester.tap(find.text('Envoyer ma proposition'));
    await tester.pumpAndSettle();
    expect(find.text('Offre envoyee'), findsOneWidget);
    expect(find.text('En attente de la reponse du client'), findsOneWidget);
    expect(find.text('2500 FCFA'), findsOneWidget);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  DriverRide? pendingRide,
  DriverRideSheetStage flowStage = DriverRideSheetStage.idle,
  double? submittedOfferPrice,
}) async {
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
                onProposePrice: _noop,
                onIgnoreRide: _noop,
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

void _noop() {}

class _DriverFlowHarness extends StatefulWidget {
  const _DriverFlowHarness();

  @override
  State<_DriverFlowHarness> createState() => _DriverFlowHarnessState();
}

class _DriverFlowHarnessState extends State<_DriverFlowHarness> {
  DriverRideSheetStage _stage = DriverRideSheetStage.rideReceived;
  double? _submittedPrice;

  @override
  Widget build(BuildContext context) {
    return DriverBottomSheet(
      driverStatus: 'online',
      isBusy: false,
      todayRides: 0,
      todayEarnings: 0,
      activeRide: null,
      pendingRide: _ride(estimatedPrice: 2500),
      flowStage: _stage,
      submittedOfferPrice: _submittedPrice,
      onStart: _noop,
      onStop: _noop,
      onOpenTracking: _noop,
      onProposePrice: () {
        setState(() => _stage = DriverRideSheetStage.priceProposal);
      },
      onIgnoreRide: _noop,
      onSubmitOffer: (price) {
        setState(() {
          _submittedPrice = price;
          _stage = DriverRideSheetStage.offerSent;
        });
      },
      onBackToRideReceived: () {
        setState(() => _stage = DriverRideSheetStage.rideReceived);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/negotiation/data/models/ride_offer_model.dart';
import 'package:noor_express_mobile/features/negotiation/presentation/widgets/offer_card.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('OfferCard displays driver, vehicle, price, distance and ETA',
      (tester) async {
    await tester.pumpWidget(
      const _OfferCardHarness(
        offer: RideOfferModel(
          offerId: 5,
          driverId: 9,
          driverName: 'Amadou',
          driverRating: 4.8,
          proposedPrice: 2800,
          status: 'pending',
          driverDistanceKm: 1.7,
          driverEtaMinutes: 6,
          driverCompletedRides: 128,
          isDriverVerified: true,
          vehicleBrand: 'Toyota',
          vehicleModel: 'Corolla',
          vehicleColor: 'blanche',
          plateNumber: 'NE-2456',
          vehiclePhoto: _transparentPixel,
        ),
      ),
    );

    expect(find.text('Amadou'), findsOneWidget);
    expect(find.text('Toyota Corolla blanche'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('2800 FCFA'), findsOneWidget);
    expect(find.text('1.7 km'), findsOneWidget);
    expect(find.text('6 min'), findsOneWidget);
    expect(find.text('128 courses'), findsOneWidget);
    expect(find.text('Verifie'), findsOneWidget);
    expect(find.text('NE-2456'), findsOneWidget);
    expect(find.text('On cherche'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets(
      'OfferCard exposes clean fallbacks when distance and ETA are absent',
      (tester) async {
    await tester.pumpWidget(
      const _OfferCardHarness(
        offer: RideOfferModel(
          offerId: 6,
          driverId: 10,
          driverName: 'Saidou',
          driverRating: 0,
          proposedPrice: 3000,
          status: 'pending',
        ),
      ),
    );

    expect(find.text('Saidou'), findsOneWidget);
    expect(find.text('Vehicule a confirmer'), findsOneWidget);
    expect(find.text('Note a confirmer'), findsOneWidget);
    expect(find.text('Distance chauffeur indisponible'), findsOneWidget);
    expect(find.text('ETA indisponible'), findsOneWidget);
  });

  testWidgets('OfferCard calls accept and reject actions', (tester) async {
    var accepted = false;
    var rejected = false;

    await tester.pumpWidget(
      _OfferCardHarness(
        offer: _offer(),
        onSelect: () => accepted = true,
        onReject: () => rejected = true,
      ),
    );

    await tester.tap(find.text('Refuser'));
    await tester.pump();
    await tester.tap(find.text('Accepter'));
    await tester.pump();

    expect(rejected, isTrue);
    expect(accepted, isTrue);
  });

  testWidgets('OfferCard shows loading only on the concerned offer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              OfferCard(
                offer: _offer(offerId: 5, driverName: 'Amadou'),
                isAccepting: true,
                onSelect: _noop,
                onReject: _noop,
              ),
              OfferCard(
                offer: _offer(offerId: 6, driverName: 'Saidou'),
                onSelect: _noop,
                onReject: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.text('Acceptation de cette offre...'), findsOneWidget);
    expect(find.text('Amadou'), findsOneWidget);
    expect(find.text('Saidou'), findsOneWidget);
  });
}

class _OfferCardHarness extends StatelessWidget {
  const _OfferCardHarness({
    required this.offer,
    this.onSelect = _noop,
    this.onReject = _noop,
  });

  final RideOfferModel offer;
  final VoidCallback onSelect;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: OfferCard(
          offer: offer,
          onSelect: onSelect,
          onReject: onReject,
        ),
      ),
    );
  }
}

RideOfferModel _offer({
  int offerId = 5,
  String driverName = 'Amadou',
}) {
  return RideOfferModel(
    offerId: offerId,
    driverId: 9,
    driverName: driverName,
    driverRating: 4.8,
    proposedPrice: 2800,
    status: 'pending',
    driverDistanceKm: 1.7,
    driverEtaMinutes: 6,
    vehicleBrand: 'Toyota',
    vehicleModel: 'Corolla',
  );
}

void _noop() {}

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lT7uigAAAABJRU5ErkJggg==';

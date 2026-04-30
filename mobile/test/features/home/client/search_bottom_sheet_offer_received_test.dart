import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/features/map/models/route_result.dart';
import 'package:noor_express_mobile/features/negotiation/data/models/ride_offer_model.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('offerReceived appears in the home sheet while map stays visible',
      (tester) async {
    var accepted = false;
    var rejected = false;

    await tester.pumpWidget(
      _Harness(
        offers: [_offer()],
        onAcceptOffer: (_) => accepted = true,
        onRejectOffer: (_) => rejected = true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('map-background')), findsOneWidget);
    expect(find.text('Offre recue'), findsOneWidget);
    expect(
      find.text('Un chauffeur vous propose un prix'),
      findsOneWidget,
    );
    expect(find.text('Grand Marche'), findsOneWidget);
    expect(find.text('Aeroport'), findsOneWidget);
    expect(find.text('2500 FCFA'), findsOneWidget);
    expect(find.text('Amadou'), findsOneWidget);
    expect(find.text('2800 FCFA'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Refuser'));
    await tester.pump();
    await tester.tap(find.text('Accepter'));
    await tester.pump();

    expect(rejected, isTrue);
    expect(accepted, isTrue);
  });

  testWidgets('offerReceived keeps only the primary offer plus see-all action',
      (tester) async {
    var openedAllOffers = false;

    await tester.pumpWidget(
      _Harness(
        offers: [
          _offer(driverName: 'Amadou', proposedPrice: 2800),
          _offer(offerId: 8, driverName: 'Saidou', proposedPrice: 3200),
        ],
        onViewAllOffers: () => openedAllOffers = true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Amadou'), findsOneWidget);
    expect(find.text('Saidou'), findsNothing);
    expect(find.text('Voir toutes les offres'), findsOneWidget);

    await tester.tap(find.text('Voir toutes les offres'));
    await tester.pump();

    expect(openedAllOffers, isTrue);
  });

  testWidgets('offerReceived shows action loading only for the concerned offer',
      (tester) async {
    await tester.pumpWidget(
      _Harness(
        offers: [_offer()],
        acceptingOfferId: 7,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.text('Acceptation de cette offre...'), findsOneWidget);
  });

  testWidgets('offered ride shows a precise loading state while offers load',
      (tester) async {
    await tester.pumpWidget(
      const _Harness(
        offers: [],
        isLoadingOffers: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Chargement des offres...'), findsOneWidget);
    expect(find.text('Voir les offres'), findsNothing);
    expect(find.text('On cherche un chauffeur'), findsNothing);
  });

  testWidgets(
      'offerReceived has clean fallback when ETA and distance are absent',
      (tester) async {
    await tester.pumpWidget(
      _Harness(
        offers: [
          _offer(
            driverDistanceKm: null,
            driverEtaMinutes: null,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Distance chauffeur indisponible'), findsOneWidget);
    expect(find.text('ETA indisponible'), findsOneWidget);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.offers,
    this.isLoadingOffers = false,
    this.acceptingOfferId,
    this.onAcceptOffer,
    this.onRejectOffer,
    this.onViewAllOffers,
  });

  final List<RideOfferModel> offers;
  final bool isLoadingOffers;
  final int? acceptingOfferId;
  final ValueChanged<RideOfferModel>? onAcceptOffer;
  final ValueChanged<RideOfferModel>? onRejectOffer;
  final VoidCallback? onViewAllOffers;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(
                key: ValueKey('map-background'),
                color: Colors.green,
              ),
            ),
            SearchBottomSheet(
              pickup: null,
              dropoff: null,
              priceController: controller,
              isCreating: false,
              isEstimatingPrice: false,
              activeRide: _ride,
              activeRideRoute: _route,
              offers: offers,
              isLoadingOffers: isLoadingOffers,
              acceptingOfferId: acceptingOfferId,
              onAcceptOffer: onAcceptOffer ?? (_) {},
              onRejectOffer: onRejectOffer ?? (_) {},
              onViewAllOffers: onViewAllOffers,
              onPickupTap: _noop,
              onDropoffTap: _noop,
              onClearPickup: _noop,
              onClearDropoff: _noop,
              onSubmit: _noop,
              onOpenActiveRide: _noop,
              onCancelActiveRide: _noop,
              recentDepartureLabels: const ['Plateau'],
            ),
          ],
        ),
      ),
    );
  }
}

final _ride = ClientRide(
  id: 42,
  pickupLocation: 'Grand Marche',
  dropoffLocation: 'Aeroport',
  status: 'offered',
  estimatedPrice: 2500,
  createdAt: DateTime(2026, 4, 24, 10),
);

const _route = RouteResult(
  polylinePoints: [LatLng(13.5, 2.1), LatLng(13.48, 2.17)],
  distanceKm: 6.4,
  durationMinutes: 18,
);

RideOfferModel _offer({
  int offerId = 7,
  String driverName = 'Amadou',
  double proposedPrice = 2800,
  double? driverDistanceKm = 1.4,
  int? driverEtaMinutes = 5,
}) {
  return RideOfferModel(
    offerId: offerId,
    driverId: 11,
    driverName: driverName,
    driverRating: 4.8,
    proposedPrice: proposedPrice,
    status: 'pending',
    driverDistanceKm: driverDistanceKm,
    driverEtaMinutes: driverEtaMinutes,
    vehicleBrand: 'Toyota',
    vehicleModel: 'Corolla',
  );
}

void _noop() {}

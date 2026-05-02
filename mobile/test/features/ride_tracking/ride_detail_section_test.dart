import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/ride_detail_section.dart';

void main() {
  testWidgets('RideDetailSection shows a receipt block for completed rides',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideDetailSection(
            ride: RideTrackingModel(
              id: 42,
              clientId: 7,
              driverId: 9,
              pickupLocation: 'Hopital National',
              dropoffLocation: 'Grand Marche',
              estimatedPrice: 2500,
              agreedPrice: 2800,
              finalPrice: 2800,
              platformCommission: 420,
              driverNetEarnings: 2380,
              distanceKm: 3.9,
              durationMinutes: 8,
              createdAt: DateTime(2026, 5, 1, 10, 15),
              completedAt: DateTime(2026, 5, 1, 10, 42),
              status: RideTrackingStatus.completed,
            ),
            counterpart: const TrackingCounterpartModel(
              id: 9,
              displayName: 'Amadou',
              phoneNumber: '+22790000000',
            ),
            roleLabel: 'Votre chauffeur',
            statusLabel: 'Trajet termine',
          ),
        ),
      ),
    );

    expect(find.text('Recu de course'), findsOneWidget);
    expect(find.text('Course #42 - 1/5/2026 a 10h42'), findsOneWidget);
    expect(find.text('3.9 km'), findsAtLeastNWidgets(1));
    expect(find.text('8 min'), findsAtLeastNWidgets(1));
    expect(find.text('Commission 420 FCFA'), findsOneWidget);
    expect(find.text('Net 2380 FCFA'), findsOneWidget);
  });
}

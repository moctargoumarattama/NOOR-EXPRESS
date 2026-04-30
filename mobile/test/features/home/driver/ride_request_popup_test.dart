import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_ride.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/widgets/ride_request_popup.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('RideRequestPopup keeps shared CTAs visible while submitting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            RideRequestPopup(
              ride: DriverRide(
                id: 1,
                pickupLocation: 'Grand Marche',
                dropoffLocation: 'Aeroport',
                status: 'pending',
                estimatedPrice: 3000,
                createdAt: DateTime(2026, 4, 24),
              ),
              isSubmitting: true,
              onSend: (_) {},
              onSkip: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byType(AppButton), findsNWidgets(2));
    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.text('Pas maintenant'), findsOneWidget);
  });

  testWidgets('RideRequestPopup labels pickup as the client pickup point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            RideRequestPopup(
              ride: DriverRide(
                id: 2,
                pickupLocation: 'Ma position actuelle',
                dropoffLocation: 'Plateau',
                status: 'pending',
                estimatedPrice: 2500,
                distanceToPickupKm: 1.2,
                createdAt: DateTime(2026, 4, 24),
              ),
              isSubmitting: false,
              onSend: (_) {},
              onSkip: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Depart : Ma position actuelle'), findsNothing);
    expect(find.text('Point de prise en charge'), findsOneWidget);
    expect(find.text('Ma position actuelle'), findsOneWidget);
    expect(find.text('A 1.2 km de vous'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Plateau'), findsOneWidget);
  });
}

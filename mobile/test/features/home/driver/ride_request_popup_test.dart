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
    expect(find.text('Passer'), findsOneWidget);
  });
}

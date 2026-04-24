import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/address_search/domain/entities/address_result.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets(
      'SearchBottomSheet shows shared loading feedback while creating a ride', (
    tester,
  ) async {
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

    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets(
      'SearchBottomSheet keeps the booking launcher and recent departures when there is no real active ride',
      (tester) async {
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
      'SearchBottomSheet does not force tracking for accepted rides on the home search sheet',
      (tester) async {
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
}

void _noop() {}

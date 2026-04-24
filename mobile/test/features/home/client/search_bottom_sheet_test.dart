import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/address_search/domain/entities/address_result.dart';
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
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });
}

void _noop() {}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/negotiation/data/models/ride_offer_model.dart';
import 'package:noor_express_mobile/features/negotiation/presentation/widgets/offer_card.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('OfferCard disables duplicate actions while busy',
      (tester) async {
    await tester.pumpWidget(const _OfferCardHarness());

    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.text('Choisir ce chauffeur'), findsOneWidget);
  });
}

class _OfferCardHarness extends StatelessWidget {
  const _OfferCardHarness();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: OfferCard(
          offer: RideOfferModel(
            offerId: 5,
            driverId: 9,
            driverName: 'Amadou',
            driverRating: 4.8,
            proposedPrice: 2800,
            status: 'pending',
          ),
          isBusy: true,
          onSelect: _noop,
          onReject: _noop,
        ),
      ),
    );
  }
}

void _noop() {}

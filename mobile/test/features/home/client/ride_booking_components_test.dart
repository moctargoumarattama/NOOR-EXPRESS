import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/theme/app_theme.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/price_selector.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/route_summary_card.dart';

void main() {
  testWidgets('RouteSummaryCard hides unreliable recommended prices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(
        child: RouteSummaryCard(
          pickupLabel: 'Grand Marche',
          dropoffLabel: 'Aeroport',
          distanceKm: 0,
          durationMinutes: 0,
          recommendedPrice: 0,
          reliabilityMessage:
              'Distance, duree et prix sont indisponibles pour ce trajet.',
        ),
      ),
    );

    expect(find.text('Grand Marche'), findsOneWidget);
    expect(find.text('Aeroport'), findsOneWidget);
    expect(find.text('Prix recommande'), findsNothing);
    expect(find.textContaining('indisponibles'), findsOneWidget);
  });

  testWidgets('PriceSelector adjusts the proposed price with plus and minus', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2500');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _Harness(
        child: PriceSelector(
          controller: controller,
          recommendedPrice: 2500,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('price-selector-increase')));
    await tester.pump();
    expect(controller.text, '2600');

    await tester.tap(find.byKey(const ValueKey('price-selector-decrease')));
    await tester.pump();
    expect(controller.text, '2500');
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }
}

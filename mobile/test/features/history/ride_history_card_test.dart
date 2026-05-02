import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/history/widgets/ride_history_card.dart';

void main() {
  testWidgets(
      'RideHistoryCard renders extra history details and completion date',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideHistoryCard(
            pickup: 'Hopital National',
            dropoff: 'Grand Marche',
            price: 2800,
            status: 'completed',
            createdAt: DateTime(2026, 5, 1, 10, 15),
            displayedAt: DateTime(2026, 5, 1, 10, 42),
            details: const [
              'Commission deduite: 420 FCFA',
              'Note recue: 4.8/5',
            ],
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Hopital National'), findsOneWidget);
    expect(find.text('Grand Marche'), findsOneWidget);
    expect(find.text('2800 FCFA'), findsOneWidget);
    expect(find.text('Commission deduite: 420 FCFA'), findsOneWidget);
    expect(find.text('Note recue: 4.8/5'), findsOneWidget);
    expect(find.text('Trajet termine'), findsOneWidget);
    expect(find.text('1/5/2026 - 10h42'), findsOneWidget);
  });
}

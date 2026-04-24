import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('AppInlineFeedback shows a recovery action for degraded states', (
    tester,
  ) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInlineFeedback(
            message: 'Reconnexion en cours...',
            tone: AppInlineFeedbackTone.warning,
            isLoading: true,
            actionLabel: 'Rafraichir l etat',
            onAction: () => refreshes++,
          ),
        ),
      ),
    );

    expect(find.text('Reconnexion en cours...'), findsOneWidget);
    expect(find.text('Rafraichir l etat'), findsOneWidget);
    await tester.tap(find.text('Rafraichir l etat'));
    expect(refreshes, 1);
  });
}

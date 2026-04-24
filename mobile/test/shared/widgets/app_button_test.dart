import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/theme/app_theme.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';

void main() {
  testWidgets(
    'AppButton blocks taps and keeps spinner inside the button while loading',
    (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppButton(
              label: 'Chercher un chauffeur',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 0);
    },
  );

  testWidgets('AppButton.danger renders without per-screen styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AppButton.danger(
            label: 'Annuler la course',
            onPressed: null,
          ),
        ),
      ),
    );

    expect(find.text('Annuler la course'), findsOneWidget);
  });
}

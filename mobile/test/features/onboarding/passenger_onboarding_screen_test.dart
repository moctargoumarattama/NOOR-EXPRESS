import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/services/passenger_onboarding_service.dart';
import 'package:noor_express_mobile/features/onboarding/presentation/screens/passenger_onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Passer amene directement au troisieme ecran', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PassengerOnboardingScreen(),
        ),
      ),
    );

    expect(find.text('Vous proposez, le chauffeur accepte'), findsOneWidget);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(find.text('Payez en cash a l arrivee'), findsOneWidget);
  });

  testWidgets('Commencer termine et ferme l onboarding', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: _OnboardingHost(),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir onboarding'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('Ecran principal'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(SharedPreferencesPassengerOnboardingStore.completedFlagKey),
      isTrue,
    );
  });
}

class _OnboardingHost extends StatelessWidget {
  const _OnboardingHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ecran principal'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PassengerOnboardingScreen(
                      onFinishedNavigation: (onboardingContext) async {
                        Navigator.of(onboardingContext).pop();
                      },
                    ),
                  ),
                );
              },
              child: const Text('Ouvrir onboarding'),
            ),
          ],
        ),
      ),
    );
  }
}

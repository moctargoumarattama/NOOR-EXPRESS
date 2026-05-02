import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:noor_express_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:noor_express_mobile/shared/screens/help_screen.dart';
import 'package:noor_express_mobile/shared/screens/notifications_screen.dart';
import 'package:noor_express_mobile/shared/screens/settings_screen.dart';
import 'package:noor_express_mobile/shared/widgets/noor_logo.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Noor Express',
      packageName: 'com.noor.express',
      version: '1.2.3',
      buildNumber: '12',
      buildSignature: '',
    );
  });

  testWidgets('LoginScreen uses a simple welcome flow', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(
      find.text('Entrez votre numero pour continuer. On s occupe du reste.'),
      findsOneWidget,
    );
    expect(find.text('CGU'), findsOneWidget);
    expect(find.text('Politique de confidentialite'), findsOneWidget);
    expect(find.text('Numero de telephone'), findsOneWidget);
    expect(find.byType(NoorLogo), findsOneWidget);
  });

  testWidgets('HelpScreen explains the ride flow with simple steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HelpScreen(),
      ),
    );

    expect(find.text('Choisissez votre destination'), findsOneWidget);
    expect(
      find.text('Indiquez le prix qui vous convient'),
      findsOneWidget,
    );
    expect(find.text('Choisissez un chauffeur'), findsOneWidget);
    expect(find.text('Suivez votre trajet simplement'), findsOneWidget);
  });

  testWidgets('RegisterScreen exposes legal links below the submit button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continuer'), findsOneWidget);
    expect(find.text('CGU'), findsOneWidget);
    expect(find.text('Politique de confidentialite'), findsOneWidget);
  });

  testWidgets('SettingsScreen keeps the account copy human and clear', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reglages'), findsOneWidget);
    expect(find.text('Position pendant un trajet'), findsOneWidget);
    expect(find.text('Version 1.2.3'), findsOneWidget);
    expect(find.text('Effacer les donnees temporaires'), findsOneWidget);
    expect(find.text('Juridique'), findsOneWidget);
    expect(find.text('CGU'), findsWidgets);
    expect(find.text('Politique de confidentialite'), findsWidgets);
    expect(
      find.text(
        'Action irreversible. Vos donnees personnelles seront anonymisees.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('SettingsScreen account deletion uses a two-step confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    expect(find.text('Etes-vous sur ?'), findsOneWidget);
    expect(
      find.text('La suppression anonymise votre compte et supprime :'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmation finale'), findsOneWidget);
    expect(find.text('SUPPRIMER'), findsOneWidget);
  });

  testWidgets('NotificationsScreen uses calm and human labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NotificationsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vos nouvelles'), findsOneWidget);
    expect(
      find.text('Les nouvelles importantes de vos trajets arrivent ici.'),
      findsOneWidget,
    );
    expect(find.text('Trajets et demandes'), findsOneWidget);
    expect(find.text('Prix et propositions'), findsOneWidget);
    expect(find.text('Suivi du trajet'), findsOneWidget);
  });
}

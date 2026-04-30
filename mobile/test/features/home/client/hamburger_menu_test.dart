import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/hamburger_menu.dart';
import 'package:noor_express_mobile/shared/widgets/noor_logo.dart';

void main() {
  testWidgets('HamburgerMenu shows the client menu sections and footer brand', (
    tester,
  ) async {
    var supportTaps = 0;
    var policyTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HamburgerMenu(
            isOpen: true,
            displayName: 'Amina Noor',
            initials: 'AN',
            phoneNumber: '+212600000000',
            onClose: _noop,
            onProfileTap: _noop,
            onHistoryTap: _noop,
            onNotificationsTap: _noop,
            onSettingsTap: _noop,
            onHelpTap: _noop,
            onSupportTap: () => supportTaps++,
            onPolicyTap: () => policyTaps++,
            onReportTap: _noop,
            onDriverModeTap: _noop,
            onLogout: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Mes trajets'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Reglages'), findsOneWidget);
    expect(find.text('Aide'), findsOneWidget);
    expect(find.text('Assistance'), findsOneWidget);
    expect(find.text('Politique d utilisation'), findsOneWidget);
    expect(find.text('Espace chauffeur'), findsOneWidget);
    expect(find.byType(NoorLogo), findsOneWidget);

    await tester.tap(find.text('Assistance'));
    await tester.tap(find.text('Politique d utilisation'));

    expect(supportTaps, 1);
    expect(policyTaps, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(find.text('Signaler un probleme'), findsOneWidget);
  });

  testWidgets('HamburgerMenu closes on a short left swipe over the panel', (
    tester,
  ) async {
    var closeTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HamburgerMenu(
            isOpen: true,
            displayName: 'Amina Noor',
            initials: 'AN',
            phoneNumber: '+212600000000',
            onClose: () => closeTaps++,
            onProfileTap: _noop,
            onHistoryTap: _noop,
            onNotificationsTap: _noop,
            onSettingsTap: _noop,
            onHelpTap: _noop,
            onSupportTap: _noop,
            onPolicyTap: _noop,
            onReportTap: _noop,
            onDriverModeTap: _noop,
            onLogout: _noop,
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('client-menu-panel')),
      const Offset(-18, 0),
    );

    expect(closeTaps, 1);
  });
}

void _noop() {}

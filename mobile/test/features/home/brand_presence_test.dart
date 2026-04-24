import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/floating_top_bar.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/hamburger_menu.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/widgets/driver_menu_header.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/widgets/driver_status_bar.dart';
import 'package:noor_express_mobile/shared/widgets/noor_logo.dart';

void main() {
  testWidgets('FloatingTopBar shows a light Noor brand signature', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FloatingTopBar(
            title: 'NOOR EXPRESS',
            initials: 'AN',
            onMenuTap: _noop,
            onProfileTap: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(NoorLogo), findsOneWidget);
  });

  testWidgets('DriverStatusBar shows a light Noor brand signature', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverStatusBar(
            status: 'online',
            onMenuTap: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(NoorLogo), findsOneWidget);
  });

  testWidgets('HamburgerMenu shows branded client header', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
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
            onReportTap: _noop,
            onDriverModeTap: _noop,
            onLogout: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(NoorLogo), findsOneWidget);
  });

  testWidgets('DriverMenuHeader shows branded driver header', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverMenuHeader(
            name: 'Amina Noor',
            profile: null,
            onTap: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(NoorLogo), findsOneWidget);
  });
}

void _noop() {}

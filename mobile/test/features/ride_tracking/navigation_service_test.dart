import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/models/app_role.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/services/navigation_service.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/services/ride_share_service.dart';
import 'package:noor_express_mobile/core/services/support_contact_service.dart';

void main() {
  const coordinates = TrackingCoordinates(
    latitude: 13.51366,
    longitude: 2.1098,
  );

  group('NavigationService app detection and launch', () {
    test('opens Waze when Waze is installed', () async {
      final launcher = _FakeNavigationUrlLauncher(
        canLaunchPredicate: (uri) => uri.scheme == 'waze',
        launchPredicate: (uri) => uri.scheme == 'waze',
      );
      final service = NavigationService(launcher: launcher);

      final plan = await service.buildLaunchPlan(coordinates);
      expect(plan.requiresUserChoice, isFalse);
      expect(plan.defaultOption.app, NavigationApp.waze);

      final launched =
          await service.openWithOption(plan.defaultOption, coordinates);
      expect(launched, isTrue);
      expect(launcher.launchedUris.single.scheme, 'waze');
    });

    test('opens Google Maps when only Google Maps is installed', () async {
      final launcher = _FakeNavigationUrlLauncher(
        canLaunchPredicate: (uri) => uri.scheme == 'google.navigation',
        launchPredicate: (uri) => uri.scheme == 'google.navigation',
      );
      final service = NavigationService(launcher: launcher);

      final plan = await service.buildLaunchPlan(coordinates);
      expect(plan.requiresUserChoice, isFalse);
      expect(plan.defaultOption.app, NavigationApp.googleMaps);

      final launched =
          await service.openWithOption(plan.defaultOption, coordinates);
      expect(launched, isTrue);
      expect(launcher.launchedUris.single.scheme, 'google.navigation');
    });

    test('falls back to web when no app is installed', () async {
      final launcher = _FakeNavigationUrlLauncher(
        canLaunchPredicate: (_) => false,
        launchPredicate: (uri) => uri.scheme == 'https',
      );
      final service = NavigationService(launcher: launcher);

      final plan = await service.buildLaunchPlan(coordinates);
      expect(plan.requiresUserChoice, isFalse);
      expect(plan.defaultOption.app, NavigationApp.web);

      final launched =
          await service.openWithOption(plan.defaultOption, coordinates);
      expect(launched, isTrue);
      expect(launcher.launchedUris.single.scheme, 'https');
    });
  });

  group('NavigationService status policy', () {
    final service = NavigationService(
      launcher: _FakeNavigationUrlLauncher(
        canLaunchPredicate: (_) => false,
        launchPredicate: (_) => false,
      ),
    );

    test('keeps destination navigation hidden before ride started', () {
      expect(
        service.canOpenDestinationNavigation(RideTrackingStatus.accepted),
        isFalse,
      );
      expect(
        service.canOpenDestinationNavigation(RideTrackingStatus.arrived),
        isFalse,
      );
      expect(
        service.canOpenDestinationNavigation(RideTrackingStatus.started),
        isTrue,
      );
    });
  });

  group('RideShareService behavior', () {
    test('opens WhatsApp when app is installed', () async {
      final launcher = _FakeRideShareUrlLauncher(
        canLaunchPredicate: (uri) => uri.scheme == 'whatsapp',
        launchPredicate: (uri) => uri.scheme == 'whatsapp',
      );
      final clipboard = _FakeRideShareClipboard();
      final service = RideShareService(
        launcher: launcher,
        clipboard: clipboard,
      );

      final result =
          await service.shareRideLink('https://example.com/track/token/map');

      expect(result.type, RideShareResultType.openedWhatsApp);
      expect(launcher.launchedUris.single.scheme, 'whatsapp');
      expect(clipboard.values, isEmpty);
    });

    test('copies link to clipboard when WhatsApp is unavailable', () async {
      final launcher = _FakeRideShareUrlLauncher(
        canLaunchPredicate: (_) => false,
        launchPredicate: (_) => false,
      );
      final clipboard = _FakeRideShareClipboard();
      final service = RideShareService(
        launcher: launcher,
        clipboard: clipboard,
      );

      final result =
          await service.shareRideLink('https://example.com/track/token/map');

      expect(result.type, RideShareResultType.copiedToClipboard);
      expect(clipboard.values.single, 'https://example.com/track/token/map');
    });

    test('exposes sharing only during accepted arrived started', () {
      final service = RideShareService(
        launcher: _FakeRideShareUrlLauncher(
          canLaunchPredicate: (_) => false,
          launchPredicate: (_) => false,
        ),
        clipboard: _FakeRideShareClipboard(),
      );

      expect(service.canShareRide(RideTrackingStatus.accepted), isTrue);
      expect(service.canShareRide(RideTrackingStatus.arrived), isTrue);
      expect(service.canShareRide(RideTrackingStatus.started), isTrue);
      expect(service.canShareRide(RideTrackingStatus.pending), isFalse);
      expect(service.canShareRide(RideTrackingStatus.completed), isFalse);
    });
  });

  group('SupportContactService behavior', () {
    test('opens WhatsApp when app is installed', () async {
      final launcher = _FakeSupportContactUrlLauncher(
        canLaunchPredicate: (uri) => uri.scheme == 'whatsapp',
        launchPredicate: (uri) => uri.scheme == 'whatsapp',
      );
      final service = SupportContactService(
        launcher: launcher,
        store: _FakeSupportContactStore(
          values: {
            'support_contact.whatsapp_phone': '+227 90 11 22 33',
          },
        ),
      );

      final result = await service.openSupportChat(AppRole.client);

      expect(result.type, SupportContactResultType.openedWhatsApp);
      expect(launcher.launchedUris.single.scheme, 'whatsapp');
    });

    test('falls back to wa.me when WhatsApp is unavailable', () async {
      final launcher = _FakeSupportContactUrlLauncher(
        canLaunchPredicate: (_) => false,
        launchPredicate: (uri) => uri.scheme == 'https' && uri.host == 'wa.me',
      );
      final service = SupportContactService(
        launcher: launcher,
        store: _FakeSupportContactStore(
          values: {
            'support_contact.whatsapp_phone': '22790112233',
          },
        ),
      );

      final result = await service.openSupportChat(AppRole.client);

      expect(result.type, SupportContactResultType.openedWebFallback);
      expect(launcher.launchedUris.single.scheme, 'https');
      expect(launcher.launchedUris.single.host, 'wa.me');
    });

    test('uses role-specific prefilled messages', () async {
      final launcher = _FakeSupportContactUrlLauncher(
        canLaunchPredicate: (uri) => uri.scheme == 'whatsapp',
        launchPredicate: (uri) => uri.scheme == 'whatsapp',
      );
      final service = SupportContactService(
        launcher: launcher,
        store: _FakeSupportContactStore(
          values: {
            'support_contact.whatsapp_phone': '22790112233',
          },
        ),
      );

      await service.openSupportChat(AppRole.client);
      await service.openSupportChat(AppRole.driver);

      final passengerText =
          launcher.launchedUris[0].queryParameters['text'] ?? '';
      final driverText = launcher.launchedUris[1].queryParameters['text'] ?? '';

      expect(passengerText, SupportContactService.passengerSupportMessage);
      expect(driverText, SupportContactService.driverSupportMessage);
    });

    test('opens terms URL with the expected legal path', () async {
      final launcher = _FakeSupportContactUrlLauncher(
        canLaunchPredicate: (_) => true,
        launchPredicate: (uri) => uri.path == '/legal/terms',
      );
      final service = SupportContactService(
        launcher: launcher,
        store: _FakeSupportContactStore(values: const {}),
      );

      final opened = await service.openTermsPage();

      expect(opened, isTrue);
      expect(launcher.launchedUris.single.path, '/legal/terms');
    });

    test('opens privacy URL with the expected legal path', () async {
      final launcher = _FakeSupportContactUrlLauncher(
        canLaunchPredicate: (_) => true,
        launchPredicate: (uri) => uri.path == '/legal/privacy',
      );
      final service = SupportContactService(
        launcher: launcher,
        store: _FakeSupportContactStore(values: const {}),
      );

      final opened = await service.openPrivacyPage();

      expect(opened, isTrue);
      expect(launcher.launchedUris.single.path, '/legal/privacy');
    });
  });
}

class _FakeNavigationUrlLauncher implements NavigationUrlLauncher {
  _FakeNavigationUrlLauncher({
    required this.canLaunchPredicate,
    required this.launchPredicate,
  });

  final bool Function(Uri uri) canLaunchPredicate;
  final bool Function(Uri uri) launchPredicate;
  final List<Uri> launchedUris = <Uri>[];

  @override
  Future<bool> canLaunch(Uri uri) async {
    return canLaunchPredicate(uri);
  }

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return launchPredicate(uri);
  }
}

class _FakeRideShareUrlLauncher implements RideShareUrlLauncher {
  _FakeRideShareUrlLauncher({
    required this.canLaunchPredicate,
    required this.launchPredicate,
  });

  final bool Function(Uri uri) canLaunchPredicate;
  final bool Function(Uri uri) launchPredicate;
  final List<Uri> launchedUris = <Uri>[];

  @override
  Future<bool> canLaunch(Uri uri) async {
    return canLaunchPredicate(uri);
  }

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return launchPredicate(uri);
  }
}

class _FakeRideShareClipboard implements RideShareClipboard {
  final List<String> values = <String>[];

  @override
  Future<void> writeText(String value) async {
    values.add(value);
  }
}

class _FakeSupportContactUrlLauncher implements SupportContactUrlLauncher {
  _FakeSupportContactUrlLauncher({
    required this.canLaunchPredicate,
    required this.launchPredicate,
  });

  final bool Function(Uri uri) canLaunchPredicate;
  final bool Function(Uri uri) launchPredicate;
  final List<Uri> launchedUris = <Uri>[];

  @override
  Future<bool> canLaunch(Uri uri) async {
    return canLaunchPredicate(uri);
  }

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return launchPredicate(uri);
  }
}

class _FakeSupportContactStore implements SupportContactStore {
  _FakeSupportContactStore({
    required Map<String, String> values,
  }) : _values = Map<String, String>.from(values);

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

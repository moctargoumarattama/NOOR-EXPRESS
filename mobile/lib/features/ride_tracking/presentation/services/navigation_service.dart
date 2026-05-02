import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/ride_tracking_model.dart';

enum NavigationApp {
  waze,
  googleMaps,
  web,
}

class NavigationOption {
  const NavigationOption._({
    required this.app,
    required this.label,
  });

  final NavigationApp app;
  final String label;

  static const waze = NavigationOption._(
    app: NavigationApp.waze,
    label: 'Waze',
  );

  static const googleMaps = NavigationOption._(
    app: NavigationApp.googleMaps,
    label: 'Google Maps',
  );

  static const web = NavigationOption._(
    app: NavigationApp.web,
    label: 'Google Maps (web)',
  );
}

class NavigationLaunchPlan {
  const NavigationLaunchPlan({
    required this.options,
  });

  final List<NavigationOption> options;

  bool get requiresUserChoice => options.length > 1;
  NavigationOption get defaultOption => options.first;
}

abstract interface class NavigationUrlLauncher {
  Future<bool> canLaunch(Uri uri);

  Future<bool> launch(Uri uri);
}

class UrlLauncherNavigationUrlLauncher implements NavigationUrlLauncher {
  const UrlLauncherNavigationUrlLauncher();

  @override
  Future<bool> canLaunch(Uri uri) {
    return canLaunchUrl(uri);
  }

  @override
  Future<bool> launch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class NavigationService {
  NavigationService({
    NavigationUrlLauncher? launcher,
  }) : _launcher = launcher ?? const UrlLauncherNavigationUrlLauncher();

  final NavigationUrlLauncher _launcher;

  bool canOpenPickupNavigation(RideTrackingStatus status) {
    return status == RideTrackingStatus.accepted ||
        status == RideTrackingStatus.arrived;
  }

  bool canOpenDestinationNavigation(RideTrackingStatus status) {
    return status == RideTrackingStatus.started;
  }

  Future<NavigationLaunchPlan> buildLaunchPlan(
    TrackingCoordinates coordinates,
  ) async {
    final options = <NavigationOption>[];

    if (await _canOpenWaze(coordinates)) {
      options.add(NavigationOption.waze);
    }
    if (await _canOpenGoogleMaps(coordinates)) {
      options.add(NavigationOption.googleMaps);
    }
    if (options.isEmpty) {
      options.add(NavigationOption.web);
    }

    return NavigationLaunchPlan(
      options: List<NavigationOption>.unmodifiable(options),
    );
  }

  Future<bool> openWithOption(
    NavigationOption option,
    TrackingCoordinates coordinates,
  ) {
    switch (option.app) {
      case NavigationApp.waze:
        return _openWaze(coordinates);
      case NavigationApp.googleMaps:
        return _openGoogleMaps(coordinates);
      case NavigationApp.web:
        return _openWeb(coordinates);
    }
  }

  Future<bool> _canOpenWaze(TrackingCoordinates coordinates) {
    return _safeCanLaunch(_wazeUri(coordinates));
  }

  Future<bool> _canOpenGoogleMaps(TrackingCoordinates coordinates) {
    return _canLaunchAny(_googleMapsCandidateUris(coordinates));
  }

  Future<bool> _openWaze(TrackingCoordinates coordinates) async {
    final launched = await _safeLaunch(_wazeUri(coordinates));
    if (launched) {
      return true;
    }
    return _openGoogleMaps(coordinates);
  }

  Future<bool> _openGoogleMaps(TrackingCoordinates coordinates) async {
    final launched =
        await _launchFirstAvailable(_googleMapsCandidateUris(coordinates));
    if (launched) {
      return true;
    }
    return _openWeb(coordinates);
  }

  Future<bool> _openWeb(TrackingCoordinates coordinates) {
    return _safeLaunch(_webGoogleMapsUri(coordinates));
  }

  Future<bool> _launchFirstAvailable(Iterable<Uri> uris) async {
    for (final uri in uris) {
      if (!await _safeCanLaunch(uri)) {
        continue;
      }
      if (await _safeLaunch(uri)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _canLaunchAny(Iterable<Uri> uris) async {
    for (final uri in uris) {
      if (await _safeCanLaunch(uri)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _safeCanLaunch(Uri uri) async {
    try {
      return await _launcher.canLaunch(uri);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeLaunch(Uri uri) async {
    try {
      return await _launcher.launch(uri);
    } catch (_) {
      return false;
    }
  }

  Iterable<Uri> _googleMapsCandidateUris(TrackingCoordinates coordinates) {
    final encodedCoordinates = _formatCoordinates(coordinates);
    return <Uri>[
      Uri.parse('google.navigation:q=$encodedCoordinates'),
      Uri.parse(
        'comgooglemaps://?daddr=$encodedCoordinates&directionsmode=driving',
      ),
      Uri.parse('geo:0,0?q=$encodedCoordinates'),
    ];
  }

  Uri _wazeUri(TrackingCoordinates coordinates) {
    final encodedCoordinates = _formatCoordinates(coordinates);
    return Uri.parse('waze://?ll=$encodedCoordinates&navigate=yes');
  }

  Uri _webGoogleMapsUri(TrackingCoordinates coordinates) {
    final encodedCoordinates = _formatCoordinates(coordinates);
    return Uri.parse('https://maps.google.com/?q=$encodedCoordinates');
  }

  String _formatCoordinates(TrackingCoordinates coordinates) {
    final latitude = coordinates.latitude.toStringAsFixed(6);
    final longitude = coordinates.longitude.toStringAsFixed(6);
    return '$latitude,$longitude';
  }
}

final navigationServiceProvider = Provider<NavigationService>((ref) {
  return NavigationService();
});

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/ride_tracking_model.dart';

enum RideShareResultType {
  openedWhatsApp,
  copiedToClipboard,
  failed,
}

class RideShareResult {
  const RideShareResult._(this.type);

  final RideShareResultType type;

  const RideShareResult.openedWhatsApp()
      : this._(RideShareResultType.openedWhatsApp);

  const RideShareResult.copiedToClipboard()
      : this._(RideShareResultType.copiedToClipboard);

  const RideShareResult.failed() : this._(RideShareResultType.failed);
}

abstract interface class RideShareUrlLauncher {
  Future<bool> canLaunch(Uri uri);

  Future<bool> launch(Uri uri);
}

class UrlLauncherRideShareUrlLauncher implements RideShareUrlLauncher {
  const UrlLauncherRideShareUrlLauncher();

  @override
  Future<bool> canLaunch(Uri uri) {
    return canLaunchUrl(uri);
  }

  @override
  Future<bool> launch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

abstract interface class RideShareClipboard {
  Future<void> writeText(String value);
}

class SystemRideShareClipboard implements RideShareClipboard {
  const SystemRideShareClipboard();

  @override
  Future<void> writeText(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }
}

class RideShareService {
  RideShareService({
    RideShareUrlLauncher? launcher,
    RideShareClipboard? clipboard,
  })  : _launcher = launcher ?? const UrlLauncherRideShareUrlLauncher(),
        _clipboard = clipboard ?? const SystemRideShareClipboard();

  final RideShareUrlLauncher _launcher;
  final RideShareClipboard _clipboard;

  bool canShareRide(RideTrackingStatus status) {
    return status == RideTrackingStatus.accepted ||
        status == RideTrackingStatus.arrived ||
        status == RideTrackingStatus.started;
  }

  Future<RideShareResult> shareRideLink(String trackingUrl) async {
    final normalizedTrackingUrl = trackingUrl.trim();
    if (normalizedTrackingUrl.isEmpty) {
      return const RideShareResult.failed();
    }

    final whatsappUri = _whatsAppUri(normalizedTrackingUrl);
    final canLaunchWhatsApp = await _safeCanLaunch(whatsappUri);
    if (canLaunchWhatsApp && await _safeLaunch(whatsappUri)) {
      return const RideShareResult.openedWhatsApp();
    }

    final copied = await _copyTrackingLink(normalizedTrackingUrl);
    if (copied) {
      return const RideShareResult.copiedToClipboard();
    }
    return const RideShareResult.failed();
  }

  Future<bool> _copyTrackingLink(String trackingUrl) async {
    try {
      await _clipboard.writeText(trackingUrl);
      return true;
    } catch (_) {
      return false;
    }
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

  Uri _whatsAppUri(String trackingUrl) {
    final message = 'Je suis en route, tu peux suivre ma position ici : '
        '$trackingUrl';
    return Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(message)}',
    );
  }
}

final rideShareServiceProvider = Provider<RideShareService>((ref) {
  return RideShareService();
});

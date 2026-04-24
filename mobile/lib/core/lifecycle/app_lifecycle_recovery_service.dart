import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef AppLifecycleResumeHandler = Future<void> Function();

class AppLifecycleRecoveryService {
  final LinkedHashMap<String, AppLifecycleResumeHandler> _resumeHandlers =
      LinkedHashMap<String, AppLifecycleResumeHandler>();

  bool _wasPaused = false;
  bool _isRecovering = false;
  bool _resumeQueued = false;

  VoidCallback registerResumeHandler(
    String key,
    AppLifecycleResumeHandler handler,
  ) {
    _resumeHandlers[key] = handler;

    return () {
      final registeredHandler = _resumeHandlers[key];
      if (registeredHandler == handler) {
        _resumeHandlers.remove(key);
      }
    };
  }

  Future<void> onLifecycleStateChanged(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        _wasPaused = true;
        return;
      case AppLifecycleState.resumed:
        if (!_wasPaused) {
          return;
        }
        _wasPaused = false;
        await _runResumeRecovery();
        return;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        return;
    }
  }

  Future<void> _runResumeRecovery() async {
    if (_isRecovering) {
      _resumeQueued = true;
      return;
    }

    _isRecovering = true;
    try {
      do {
        _resumeQueued = false;
        final handlers = List<MapEntry<String, AppLifecycleResumeHandler>>.from(
          _resumeHandlers.entries,
        );
        await Future.wait(
          handlers.map((entry) async {
            try {
              await entry.value();
            } catch (error, stackTrace) {
              debugPrint(
                '[lifecycle] resume handler ${entry.key} failed: $error',
              );
              debugPrintStack(stackTrace: stackTrace);
            }
          }),
        );
      } while (_resumeQueued);
    } finally {
      _isRecovering = false;
    }
  }
}

final appLifecycleRecoveryServiceProvider =
    Provider<AppLifecycleRecoveryService>((ref) {
  return AppLifecycleRecoveryService();
});

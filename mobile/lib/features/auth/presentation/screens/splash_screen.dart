import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/connectivity_fallback_view.dart';
import '../../../../shared/widgets/noor_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.microtask(_restore);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_isRestoring) {
      return;
    }
    _isRestoring = true;
    try {
      await ref.read(sessionControllerProvider.notifier).restoreSession().timeout(
            const Duration(seconds: 12),
            onTimeout: () async {
              ref.read(sessionControllerProvider.notifier).markRestoreFailure(
                    message:
                        'Delai depasse. La connexion est trop lente pour le moment.',
                    type: ApiIssueType.timeout,
                  );
            },
          );
    } finally {
      _isRestoring = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final showRestoreError = session.status == SessionStatus.restoreFailed;

    return Scaffold(
      backgroundColor: AppColors.pearl,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pearl,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: const NoorLogo.hero(),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 6),
                    Text(
                      'Ouverture en cours...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.stone,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showRestoreError)
            Positioned.fill(
              child: ConnectivityFallbackView(
                issueType: session.restoreFailureType,
                message: session.errorMessage,
                onRetry: _restore,
              ),
            ),
        ],
      ),
    );
  }
}

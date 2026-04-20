import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(sessionControllerProvider.notifier).restoreSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.ink,
              AppColors.midnight,
              Color(0xFF293B57),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  size: 42,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Noor Express',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.pearl,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Fondations Flutter premium pour votre VTC.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.pearl.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

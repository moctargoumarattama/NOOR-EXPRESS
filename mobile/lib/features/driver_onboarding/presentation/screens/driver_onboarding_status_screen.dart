import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/driver_profile_model.dart';
import '../controllers/onboarding_controller.dart';

class DriverOnboardingStatusScreen extends ConsumerStatefulWidget {
  const DriverOnboardingStatusScreen({super.key});

  @override
  ConsumerState<DriverOnboardingStatusScreen> createState() =>
      _DriverOnboardingStatusScreenState();
}

class _DriverOnboardingStatusScreenState
    extends ConsumerState<DriverOnboardingStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(driverOnboardingControllerProvider.notifier).load();
      if (!mounted) {
        return;
      }
      final state = ref.read(driverOnboardingControllerProvider);
      if (state.profile == null && state.errorMessage == null) {
        context.go(AppRoutes.driverOnboarding);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverOnboardingControllerProvider);
    final profile = state.profile;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _StatusCard(
                      profile: profile,
                      errorMessage: state.errorMessage,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.profile,
    required this.errorMessage,
  });

  final DriverOnboardingProfileModel? profile;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    final content = _content(profile, errorMessage);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: content.color.withValues(alpha: 0.12),
            child: Icon(content.icon, color: content.color, size: 42),
          ),
          const SizedBox(height: 20),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            content.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.stone, height: 1.4),
          ),
          if (content.reason != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                content.reason!,
                style: const TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (currentProfile != null &&
              currentProfile.documentExpiryAlerts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ExpiryAlertBox(alerts: currentProfile.documentExpiryAlerts),
          ],
          const SizedBox(height: 24),
          AppButton(
              label: content.primaryLabel,
              onPressed: content.primaryTap(context)),
          const SizedBox(height: 10),
          AppButton.secondary(
            label: 'Retour a l accueil',
            onPressed: () => context.go(AppRoutes.driverHome),
          ),
        ],
      ),
    );
  }

  _StatusContent _content(
    DriverOnboardingProfileModel? profile,
    String? errorMessage,
  ) {
    if (profile == null) {
      return _StatusContent(
        icon: Icons.assignment_rounded,
        color: AppColors.emerald,
        title: 'Dossier driver requis',
        message: errorMessage ?? 'Completez votre dossier pour etre verifie.',
        primaryLabel: 'Completer mon dossier',
        primaryTap: (context) => () => context.go(AppRoutes.driverOnboarding),
      );
    }
    switch (profile.verificationStatus) {
      case DriverVerificationStatus.verified:
        return _StatusContent(
          icon: Icons.verified_rounded,
          color: AppColors.emerald,
          title: 'Compte verifie !',
          message: 'Vous pouvez maintenant recevoir des courses.',
          primaryLabel: 'Commencer',
          primaryTap: (context) => () => context.go(AppRoutes.driverHome),
        );
      case DriverVerificationStatus.rejected:
        return _StatusContent(
          icon: Icons.cancel_rounded,
          color: AppColors.coral,
          title: 'Dossier non accepte',
          message: 'Corrigez votre dossier et resoumettez-le.',
          reason: profile.rejectionReason,
          primaryLabel: 'Resoumettre',
          primaryTap: (context) => () => context.go(AppRoutes.driverOnboarding),
        );
      case DriverVerificationStatus.pending:
        final etaMessage = _pendingEtaMessage(profile.submittedAt);
        return _StatusContent(
          icon: Icons.hourglass_top_rounded,
          color: AppColors.gold,
          title: 'En attente de validation',
          message: etaMessage,
          primaryLabel: 'Rafraichir le statut',
          primaryTap: (context) => () => context.go(AppRoutes.driverOnboardingStatus),
        );
    }
  }

  String _pendingEtaMessage(DateTime? submittedAt) {
    if (submittedAt == null) {
      return 'Notre equipe examine vos documents. Delai estime: moins de 24h.';
    }

    final eta = submittedAt.add(const Duration(hours: 24));
    final remaining = eta.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'Votre dossier est toujours en attente de validation. Delai estime depasse, notre equipe le traite en priorite.';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final timeLeft = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';
    return 'Votre dossier est en attente de validation. Delai estime restant: $timeLeft.';
  }
}

class _ExpiryAlertBox extends StatelessWidget {
  const _ExpiryAlertBox({required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document a renouveler bientot',
            style: TextStyle(
              color: Color(0xFF8A5A00),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final alert in alerts)
            Text(
              alert,
              style: const TextStyle(
                color: Color(0xFF8A5A00),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusContent {
  const _StatusContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryTap,
    this.reason,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String primaryLabel;
  final String? reason;
  final VoidCallback Function(BuildContext context) primaryTap;
}

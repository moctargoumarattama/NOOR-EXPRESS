import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../driver_onboarding/data/models/driver_profile_model.dart';

class DriverVerificationCard extends StatelessWidget {
  const DriverVerificationCard({super.key, required this.profile});

  final DriverOnboardingProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final status = profile?.verificationStatus;
    final palette = _palette(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: palette.color.withValues(alpha: 0.12),
                child: Icon(palette.icon, color: palette.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  palette.label,
                  style: TextStyle(
                    color: palette.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (profile?.rejectionReason?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              profile!.rejectionReason!,
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.driverOnboardingStatus),
                  child: const Text('Voir mon dossier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: status == DriverVerificationStatus.verified
                      ? null
                      : () => context.push(AppRoutes.driverOnboarding),
                  child: const Text('Modifier'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _VerificationPalette _palette(DriverVerificationStatus? status) {
    switch (status) {
      case DriverVerificationStatus.verified:
        return const _VerificationPalette(
          label: 'Compte verifie',
          icon: Icons.verified_rounded,
          color: Color(0xFF1B8A5A),
        );
      case DriverVerificationStatus.rejected:
        return const _VerificationPalette(
          label: 'Dossier rejete',
          icon: Icons.cancel_rounded,
          color: Color(0xFFE53935),
        );
      case DriverVerificationStatus.pending:
        return const _VerificationPalette(
          label: 'En attente de validation',
          icon: Icons.hourglass_top_rounded,
          color: Color(0xFFF5A623),
        );
      case null:
        return const _VerificationPalette(
          label: 'Dossier non soumis',
          icon: Icons.assignment_rounded,
          color: Color(0xFFF5A623),
        );
    }
  }
}

class _VerificationPalette {
  const _VerificationPalette({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

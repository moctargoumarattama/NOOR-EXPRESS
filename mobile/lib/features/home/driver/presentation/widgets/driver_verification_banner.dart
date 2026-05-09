import 'package:flutter/material.dart';

import '../../../../driver_onboarding/data/models/driver_profile_model.dart';

class DriverVerificationBanner extends StatelessWidget {
  const DriverVerificationBanner({
    super.key,
    required this.profile,
    required this.onTap,
  });

  final DriverOnboardingProfileModel? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rejected =
        profile?.verificationStatus == DriverVerificationStatus.rejected;
    final color = rejected ? const Color(0xFFE53935) : const Color(0xFFF5A623);
    final label = profile == null
        ? 'Completez votre dossier driver'
        : rejected
            ? 'Dossier rejete - cliquez pour corriger'
            : 'En attente de validation admin';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                rejected ? Icons.error_rounded : Icons.hourglass_top_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

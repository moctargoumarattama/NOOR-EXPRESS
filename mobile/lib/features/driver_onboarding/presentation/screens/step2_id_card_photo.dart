import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';

class Step2IdCardPhoto extends StatelessWidget {
  const Step2IdCardPhoto({
    super.key,
    required this.photo,
    required this.onCamera,
    required this.onGallery,
    required this.onBack,
    required this.onNext,
  });

  final String? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _PhotoStepCard(
      title: 'Votre piece d identite',
      subtitle: 'Prenez une photo nette de votre piece d identite.',
      icon: Icons.badge_rounded,
      placeholderIcon: Icons.photo_camera_rounded,
      placeholderText: 'Touchez ici pour prendre la photo',
      photo: photo,
      checks: const ['Recto lisible', 'Bonne luminosite', 'Pas de reflet'],
      primaryLabel: 'Prendre une photo',
      secondaryLabel: 'Choisir dans la galerie',
      onCamera: onCamera,
      onGallery: onGallery,
      onBack: onBack,
      onNext: photo == null ? null : onNext,
    );
  }
}

class _PhotoStepCard extends StatelessWidget {
  const _PhotoStepCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.placeholderIcon,
    required this.placeholderText,
    required this.photo,
    required this.checks,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onCamera,
    required this.onGallery,
    required this.onBack,
    required this.onNext,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData placeholderIcon;
  final String placeholderText;
  final String? photo;
  final List<String> checks;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bytes = photo == null ? null : base64Decode(photo!);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mint,
                child: Icon(icon, color: AppColors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: AppColors.stone)),
          const SizedBox(height: 18),
          InkWell(
            onTap: onCamera,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: bytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          placeholderIcon,
                          size: 42,
                          color: AppColors.emerald,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          placeholderText,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          ...checks.map((item) => _CheckItem(label: item)),
          const SizedBox(height: 18),
          AppButton(label: primaryLabel, onPressed: onCamera),
          const SizedBox(height: 10),
          AppButton.secondary(label: secondaryLabel, onPressed: onGallery),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child:
                      AppButton.secondary(label: 'Retour', onPressed: onBack)),
              const SizedBox(width: 12),
              Expanded(child: AppButton(label: 'Suivant', onPressed: onNext)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';

class Step3Selfie extends StatelessWidget {
  const Step3Selfie({
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
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mint,
                child: Icon(Icons.face_rounded, color: AppColors.emerald),
              ),
              SizedBox(width: 12),
              Text(
                'Votre selfie',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Prenez un selfie clair pour confirmer votre identite.',
            style: TextStyle(color: AppColors.stone),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onCamera,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: bytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_front_rounded,
                          size: 46,
                          color: AppColors.emerald,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Touchez pour prendre la photo',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
          const _CheckItem(label: 'Visage bien visible'),
          const _CheckItem(label: 'Bonne luminosite'),
          const _CheckItem(label: 'Fond neutre'),
          const SizedBox(height: 18),
          AppButton(label: 'Prendre un selfie', onPressed: onCamera),
          const SizedBox(height: 10),
          AppButton.secondary(
            label: 'Choisir dans la galerie',
            onPressed: onGallery,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child:
                      AppButton.secondary(label: 'Retour', onPressed: onBack)),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Suivant',
                  onPressed: photo == null ? null : onNext,
                ),
              ),
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

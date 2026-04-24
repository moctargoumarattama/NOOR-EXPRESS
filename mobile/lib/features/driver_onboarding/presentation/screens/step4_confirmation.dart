import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';

class Step4Confirmation extends StatelessWidget {
  const Step4Confirmation({
    super.key,
    required this.fullName,
    required this.address,
    required this.idCardPhoto,
    required this.selfiePhoto,
    required this.isSubmitting,
    required this.onBack,
    required this.onSubmit,
  });

  final String fullName;
  final String address;
  final String? idCardPhoto;
  final String? selfiePhoto;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
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
                child:
                    Icon(Icons.verified_user_rounded, color: AppColors.emerald),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verifiez vos informations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoLine(icon: Icons.person_rounded, label: fullName),
          _InfoLine(icon: Icons.location_on_rounded, label: address),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _MiniPhoto(label: 'CNI', photo: idCardPhoto)),
              const SizedBox(width: 12),
              Expanded(child: _MiniPhoto(label: 'Selfie', photo: selfiePhoto)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Nous verifierons vos documents le plus vite possible.',
              style: TextStyle(
                color: Color(0xFF8A5A00),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child:
                      AppButton.secondary(label: 'Retour', onPressed: onBack)),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: isSubmitting ? 'Envoi...' : 'Envoyer',
                  onPressed: isSubmitting ? null : onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPhoto extends StatelessWidget {
  const _MiniPhoto({required this.label, required this.photo});

  final String label;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final bytes = photo == null ? null : base64Decode(photo!);
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Center(child: Text('$label manquant'))
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Text(
                      '$label OK',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

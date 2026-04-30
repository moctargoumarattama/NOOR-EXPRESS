import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class UsagePolicyScreen extends StatelessWidget {
  const UsagePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _Header(
              title: 'Politique d utilisation',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 20),
            const _PolicyPanel(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PolicyPanel extends StatelessWidget {
  const _PolicyPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppColors.emerald),
            SizedBox(height: 14),
            Text(
              'Regles d utilisation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Cette page affichera la politique complete de Noor Express. '
              'En attendant, utilisez l application de maniere respectueuse, '
              'gardez vos informations de trajet exactes et signalez tout '
              'probleme depuis le menu.',
              style: TextStyle(color: AppColors.stone, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

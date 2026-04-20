import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class DriverOnboardingHeader extends StatelessWidget {
  const DriverOnboardingHeader({super.key, required this.onBack});

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
        const Expanded(
          child: Text(
            'Verification driver',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class DriverOnboardingStepper extends StatelessWidget {
  const DriverOnboardingStepper({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Infos', 'ID', 'Selfie', 'Envoi'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: _StepDot(index: index, label: labels[index], step: step),
            ),
            if (index != labels.length - 1)
              Container(width: 18, height: 2, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class DriverOnboardingErrorBox extends StatelessWidget {
  const DriverOnboardingErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.coral,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.step,
  });

  final int index;
  final String label;
  final int step;

  @override
  Widget build(BuildContext context) {
    final active = index <= step;
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: active ? AppColors.emerald : AppColors.border,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: active ? Colors.white : AppColors.stone,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

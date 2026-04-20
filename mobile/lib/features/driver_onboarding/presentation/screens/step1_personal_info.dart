import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';

class Step1PersonalInfo extends StatelessWidget {
  const Step1PersonalInfo({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.addressController,
    required this.phoneNumber,
    required this.onNext,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController addressController;
  final String phoneNumber;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Vos informations',
      icon: Icons.person_rounded,
      children: [
        TextField(
          controller: firstNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Prenom *'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: lastNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nom *'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          readOnly: true,
          initialValue: phoneNumber,
          decoration: const InputDecoration(labelText: 'Telephone'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: addressController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Adresse a Niamey *'),
        ),
        const SizedBox(height: 22),
        AppButton(label: 'Suivant', onPressed: onNext),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mint,
                child: Icon(icon, color: AppColors.emerald),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

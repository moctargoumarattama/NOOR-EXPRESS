import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class RegisterAuthLogo extends StatelessWidget {
  const RegisterAuthLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.emerald,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_taxi_rounded,
        color: AppColors.pearl,
        size: 30,
      ),
    );
  }
}

class RegisterPrimaryButton extends StatelessWidget {
  const RegisterPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.pearl,
          shadowColor: AppColors.emerald.withValues(alpha: 0.3),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.pearl,
                  ),
                )
              : Text(
                  '$label  ->',
                  key: const ValueKey('label'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

class RegisterRoleSelector extends ConsumerWidget {
  const RegisterRoleSelector({super.key, required this.selectedRole});

  final AppRole selectedRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: RegisterRoleTile(
            label: 'Passager',
            icon: Icons.person_rounded,
            isSelected: selectedRole == AppRole.client,
            onTap: () => ref
                .read(authControllerProvider.notifier)
                .selectRole(AppRole.client),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RegisterRoleTile(
            label: 'Chauffeur',
            icon: Icons.local_taxi_rounded,
            isSelected: selectedRole == AppRole.driver,
            onTap: () => ref
                .read(authControllerProvider.notifier)
                .selectRole(AppRole.driver),
          ),
        ),
      ],
    );
  }
}

class RegisterRoleTile extends StatelessWidget {
  const RegisterRoleTile({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.emerald : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.pearl : AppColors.emerald,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.pearl : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterErrorBox extends StatelessWidget {
  const RegisterErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF9F2D20),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

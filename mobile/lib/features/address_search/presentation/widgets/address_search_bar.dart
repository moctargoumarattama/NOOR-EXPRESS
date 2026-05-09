import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AddressSearchBar extends StatelessWidget {
  const AddressSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hintText = 'Rechercher une adresse...',
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search_rounded,
            color: AppColors.nigerOrange,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              if (!hasText || !enabled) {
                return const SizedBox(width: 12);
              }
              return IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  focusNode.requestFocus();
                },
                splashRadius: 22,
                iconSize: 20,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

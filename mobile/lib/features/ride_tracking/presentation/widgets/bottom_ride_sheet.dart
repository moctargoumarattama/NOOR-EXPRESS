import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class BottomRideSheet extends StatelessWidget {
  const BottomRideSheet({
    super.key,
    required this.child,
    this.primaryAction,
    this.secondaryAction,
    this.floatingAction,
  });

  final Widget child;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.pearl,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 26,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  child,
                  if (secondaryAction != null || primaryAction != null) ...[
                    const SizedBox(height: 14),
                    if (secondaryAction != null) secondaryAction!,
                    if (secondaryAction != null && primaryAction != null)
                      const SizedBox(height: 10),
                    if (primaryAction != null) primaryAction!,
                  ],
                ],
              ),
            ),
            if (floatingAction != null)
              Positioned(
                right: 14,
                top: -24,
                child: floatingAction!,
              ),
          ],
        ),
      ),
    );
  }
}

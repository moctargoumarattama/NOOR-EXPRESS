import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/address_result.dart';

class AddressResultTile extends StatefulWidget {
  const AddressResultTile({
    super.key,
    required this.result,
    required this.onTap,
    this.icon = Icons.location_on_rounded,
    this.trailing,
  });

  final AddressResult result;
  final VoidCallback onTap;
  final IconData icon;
  final Widget? trailing;

  @override
  State<AddressResultTile> createState() => _AddressResultTileState();
}

class _AddressResultTileState extends State<AddressResultTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.result.isKnownZone || widget.result.isCurrentLocation
        ? AppColors.nigerGreen
        : AppColors.nigerOrange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _pressed ? 0.98 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.backgroundSubtle : AppColors.pearl,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _pressed = false);
                widget.onTap();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.result.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.result.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 10),
                      widget.trailing!,
                    ] else ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

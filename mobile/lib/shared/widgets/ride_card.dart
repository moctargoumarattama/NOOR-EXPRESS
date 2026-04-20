import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_surface_card.dart';
import 'status_badge.dart';

class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.metaChildren,
    this.footer,
    this.highlight = false,
  });

  final String pickup;
  final String dropoff;
  final String status;
  final List<Widget> metaChildren;
  final Widget? footer;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: highlight
            ? const [
                BoxShadow(
                  color: Color(0x22F2B84B),
                  blurRadius: 26,
                  offset: Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pickup,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.south_rounded,
                  size: 18,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dropoff,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metaChildren,
            ),
            if (footer != null) ...[
              const SizedBox(height: 18),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

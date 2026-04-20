import 'package:flutter/material.dart';

import '../../../../address_search/domain/entities/address_result.dart';

class AddressInputCard extends StatelessWidget {
  const AddressInputCard({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const _RouteDot(color: Color(0xFF1B8A5A)),
              Container(
                width: 3,
                height: 54,
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B8A5A).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const _RouteDot(color: Color(0xFFE5484D)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _AddressRow(
                  title: 'Votre position',
                  value: pickup?.name ?? 'Choisir le depart',
                  subtitle: pickup?.displayName,
                  onTap: onPickupTap,
                  onClear: pickup == null ? null : onClearPickup,
                ),
                const Divider(height: 14, color: Color(0xFFF0F0F0)),
                _AddressRow(
                  title: 'Destination',
                  value: dropoff?.name ?? 'Ou allez-vous ?',
                  subtitle: dropoff?.displayName,
                  onTap: onDropoffTap,
                  onClear: dropoff == null ? null : onClearDropoff,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.onClear,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF757575),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF757575),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onClear ?? onTap,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                onClear == null ? Icons.chevron_right_rounded : Icons.close,
                color: const Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

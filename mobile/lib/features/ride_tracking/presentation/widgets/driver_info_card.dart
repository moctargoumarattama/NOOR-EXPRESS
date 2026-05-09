import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/ride_tracking_model.dart';

class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.counterpart,
    required this.priceLabel,
    required this.roleLabel,
  });

  final TrackingCounterpartModel counterpart;
  final String priceLabel;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.nigerGreenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: _vehiclePreview(counterpart),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counterpart.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (counterpart.vehicleLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        counterpart.vehicleLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.nigerGreenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  priceLabel,
                  style: const TextStyle(
                    color: AppColors.nigerGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.star_rounded,
                label: counterpart.rating == null
                    ? 'Note a confirmer'
                    : counterpart.rating!.toStringAsFixed(1),
              ),
              if (counterpart.plateNumber != null &&
                  counterpart.plateNumber!.trim().isNotEmpty)
                _InfoPill(
                  icon: Icons.directions_car_filled_rounded,
                  label: counterpart.plateNumber!,
                ),
              _InfoPill(
                icon: Icons.call_outlined,
                label: counterpart.phoneNumber,
                foregroundColor: AppColors.textSecondary,
                iconColor: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehiclePreview(TrackingCounterpartModel counterpart) {
    final Uint8List? bytes = _decodeVehiclePhoto(counterpart.vehiclePhoto);
    if (bytes == null) {
      return Center(
        child: Text(
          counterpart.avatarLabel,
          style: const TextStyle(
            color: AppColors.nigerGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return const Icon(
          Icons.directions_car_rounded,
          color: AppColors.nigerGreen,
        );
      },
    );
  }
}

Uint8List? _decodeVehiclePhoto(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.foregroundColor = AppColors.textPrimary,
    this.iconColor = AppColors.nigerGreen,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

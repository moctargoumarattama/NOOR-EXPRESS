import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../data/models/driver_profile.dart';

class DriverMenuHeader extends StatelessWidget {
  const DriverMenuHeader({
    super.key,
    required this.name,
    required this.profile,
    required this.onTap,
  });

  final String name;
  final DriverProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoBytes = _decodePhoto(profile?.profilePhoto);
    final vehicle = [
      profile?.vehicleBrand,
      profile?.vehicleModel,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');
    final plate = profile?.plateNumber?.trim() ?? '';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2FBF7),
            Color(0xFFE4F4EC),
          ],
        ),
        border: Border.all(
          color: AppColors.nigerGreenBorder.withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.nigerGreen.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColors.nigerGreen.withValues(alpha: 0.10),
          highlightColor: AppColors.nigerGreen.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFF5FBF8),
                  backgroundImage:
                      photoBytes == null ? null : MemoryImage(photoBytes),
                  child: photoBytes == null
                      ? Text(
                          _initials(name),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.nigerGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.nigerGreenSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Chauffeur',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.nigerGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Espace conducteur',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (vehicle.isNotEmpty || plate.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [vehicle, plate]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.nigerGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'D';
    }
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$second'.toUpperCase();
  }

  Uint8List? _decodePhoto(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final payload = value.contains(',') ? value.split(',').last : value;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}

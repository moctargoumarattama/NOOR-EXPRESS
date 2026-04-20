import 'package:flutter/material.dart';

import '../../data/models/driver_profile.dart';
import '../../data/models/driver_stats.dart';
import '../../../../profile/presentation/widgets/profile_avatar.dart';

class DriverIdentityBlock extends StatelessWidget {
  const DriverIdentityBlock({
    super.key,
    required this.profile,
    required this.isPhotoSaving,
    required this.onPhotoTap,
  });

  final DriverProfile? profile;
  final bool isPhotoSaving;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final name = profile?.name?.trim().isNotEmpty == true
        ? profile!.name!
        : 'Driver Noor';
    return Column(
      children: [
        ProfileAvatar(
          initials: _initials(name),
          profilePhoto: profile?.profilePhoto,
          isLoading: isPhotoSaving,
          onTap: onPhotoTap,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isPhotoSaving ? null : onPhotoTap,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(isPhotoSaving ? 'Envoi...' : 'Changer la photo'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1B8A5A),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(profile?.phoneNumber ?? '',
            style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'DN';
    }
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$second'.toUpperCase();
  }
}

class DriverProfileStatsBlock extends StatelessWidget {
  const DriverProfileStatsBlock({super.key, required this.stats});

  final DriverStats? stats;

  @override
  Widget build(BuildContext context) {
    final data = stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                  value: '${data?.totalRides ?? 0}', label: 'courses'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                value:
                    '⭐ ${(data?.averageRatingFromClients ?? 0).toStringAsFixed(1)}',
                label: 'note',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total gains'),
              const SizedBox(height: 6),
              Text(
                '${(data?.totalEarnings ?? 0).toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  color: Color(0xFF1B8A5A),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DriverProfileErrorCard extends StatelessWidget {
  const DriverProfileErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: const TextStyle(color: Colors.red));
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

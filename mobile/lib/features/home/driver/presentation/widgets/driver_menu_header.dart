import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/noor_logo.dart';
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
    final photoBytes = _decodePhoto(profile?.profilePhoto);
    final vehicle = [
      profile?.vehicleBrand,
      profile?.vehicleModel,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: NoorLogo.header(width: 150),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE8F5E9),
                backgroundImage:
                    photoBytes == null ? null : MemoryImage(photoBytes),
                child: photoBytes == null
                    ? Text(
                        _initials(name),
                        style: const TextStyle(
                          color: Color(0xFF1B8A5A),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Etoile 4.7 (45 courses)'),
                    if (vehicle.isNotEmpty) Text(vehicle),
                    if ((profile?.plateNumber ?? '').isNotEmpty)
                      Text(profile!.plateNumber!),
                    const SizedBox(height: 3),
                    const Text(
                      'Voir profil',
                      style: TextStyle(
                        color: Color(0xFF1B8A5A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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

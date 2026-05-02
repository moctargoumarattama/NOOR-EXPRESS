import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.profilePhoto,
    this.localPhotoBytes,
    this.isLoading = false,
    this.onTap,
  });

  final String initials;
  final String? profilePhoto;
  final Uint8List? localPhotoBytes;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = localPhotoBytes ?? _decodeImage(profilePhoto);
    final imageUrl =
        localPhotoBytes == null ? _readImageUrl(profilePhoto) : null;
    final canTap = onTap != null && !isLoading;

    return Semantics(
      button: canTap,
      label: 'Changer la photo de profil',
      child: MouseRegion(
        cursor: canTap ? SystemMouseCursors.click : MouseCursor.defer,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: canTap ? onTap : null,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.emerald, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildAvatarImage(bytes, imageUrl),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      key: ValueKey(isLoading),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(Uint8List? bytes, String? imageUrl) {
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _InitialsAvatar(initials: initials),
      );
    }
    return _InitialsAvatar(initials: initials);
  }

  Uint8List? _decodeImage(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (_readImageUrl(value) != null) {
      return null;
    }
    try {
      final payload = value.contains(',') ? value.split(',').last : value;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  String? _readImageUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final candidate = value.trim();
    if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
      return candidate;
    }
    if (candidate.startsWith('/uploads/')) {
      return '${AppConfig.apiBaseUrl}$candidate';
    }
    return null;
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.emerald,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

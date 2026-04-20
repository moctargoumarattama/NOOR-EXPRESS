import 'dart:ui';

import 'package:flutter/material.dart';

class DriverStatusBar extends StatelessWidget {
  const DriverStatusBar({
    super.key,
    required this.status,
    required this.onMenuTap,
  });

  final String status;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu_rounded),
              ),
              const Expanded(
                child: Text(
                  'NOOR EXPRESS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      palette.label,
                      style: TextStyle(
                        color: palette.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusPalette _palette(String value) {
    switch (value) {
      case 'busy':
        return const _StatusPalette(
          label: 'BUSY',
          background: Color(0xFFFFF4E0),
          foreground: Color(0xFFF5A623),
        );
      case 'online':
        return const _StatusPalette(
          label: 'EN LIGNE',
          background: Color(0xFFE8F5E9),
          foreground: Color(0xFF1B8A5A),
        );
      default:
        return const _StatusPalette(
          label: 'OFFLINE',
          background: Color(0xFFFFECEA),
          foreground: Color(0xFFE53935),
        );
    }
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

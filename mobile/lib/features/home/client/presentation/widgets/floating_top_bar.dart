import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/noor_logo.dart';

class FloatingTopBar extends StatelessWidget {
  const FloatingTopBar({
    super.key,
    required this.title,
    required this.initials,
    required this.onMenuTap,
    required this.onProfileTap,
    this.hasNotification = false,
    this.showBrandLogo = true,
  });

  final String title;
  final String initials;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;
  final bool hasNotification;
  final bool showBrandLogo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _TopAction(
                icon: Icons.menu_rounded,
                onPressed: onMenuTap,
              ),
              Expanded(
                child: Center(
                  child: showBrandLogo
                      ? const NoorLogo.compact()
                      : Text(
                          title,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B8A5A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (hasNotification)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5484D),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: const Color(0xFF1A1A1A),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

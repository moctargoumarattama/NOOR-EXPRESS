import 'dart:math' as math;

import 'package:flutter/material.dart';

class CarMarker extends StatelessWidget {
  const CarMarker({
    super.key,
    required this.headingDegrees,
  });

  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Driver disponible',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.85 + (opacity * 0.15),
              child: child,
            ),
          );
        },
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: headingDegrees * math.pi / 180,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_taxi_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

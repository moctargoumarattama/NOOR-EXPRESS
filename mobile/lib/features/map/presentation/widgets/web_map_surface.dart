import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/map_point.dart';
import '../../data/models/realtime_driver_marker.dart';

class WebMapSurface extends StatelessWidget {
  const WebMapSurface({
    super.key,
    required this.center,
    required this.drivers,
    required this.primaryLabel,
    required this.primaryColor,
  });

  final MapPoint? center;
  final List<RealtimeDriverMarker> drivers;
  final String primaryLabel;
  final Color primaryColor;

  static const double _latitudeSpan = 0.08;
  static const double _longitudeSpan = 0.08;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FAFF),
            Color(0xFFF1F5FB),
            Color(0xFFE8EEF8),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _WebMapGrid()),
          LayoutBuilder(
            builder: (context, constraints) {
              final markerWidgets = <Widget>[];

              if (center != null) {
                final centerOffset = _projectOffset(
                  point: center!,
                  centerPoint: center!,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                );
                markerWidgets.add(
                  _buildMarker(
                    offset: centerOffset,
                    label: primaryLabel,
                    color: primaryColor,
                    isPrimary: true,
                  ),
                );
              }

              for (final driver in drivers) {
                final point = driver.position;
                final centerPoint = center ?? point;
                final offset = _projectOffset(
                  point: point,
                  centerPoint: centerPoint,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                );
                markerWidgets.add(
                  _buildMarker(
                    offset: offset,
                    label: 'D${driver.driverId}',
                    color: AppColors.gold,
                  ),
                );
              }

              return Stack(children: markerWidgets);
            },
          ),
          Positioned(
            top: 18,
            left: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                'Vue web legere',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1726).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${drivers.length} driver${drivers.length > 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.pearl,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (center == null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'La carte web reste en mode simplifie tant que la position n est pas disponible.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarker({
    required Offset offset,
    required String label,
    required Color color,
    bool isPrimary = false,
  }) {
    final size = isPrimary ? 24.0 : 18.0;

    return Positioned(
      left: offset.dx - (size / 2),
      top: offset.dy - (size / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _projectOffset({
    required MapPoint point,
    required MapPoint centerPoint,
    required double width,
    required double height,
  }) {
    final normalizedX =
        ((point.longitude - centerPoint.longitude) / _longitudeSpan) + 0.5;
    final normalizedY =
        0.5 - ((point.latitude - centerPoint.latitude) / _latitudeSpan);

    final clampedX = normalizedX.clamp(0.1, 0.9).toDouble();
    final clampedY = normalizedY.clamp(0.14, 0.86).toDouble();

    return Offset(
      math.max(24, width * clampedX),
      math.max(24, height * clampedY),
    );
  }
}

class _WebMapGrid extends StatelessWidget {
  const _WebMapGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WebMapGridPainter(),
    );
  }
}

class _WebMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE5F2)
      ..strokeWidth = 1;

    for (var i = 1; i < 6; i++) {
      final dx = size.width * (i / 6);
      final dy = size.height * (i / 6);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }

    final accentPaint = Paint()
      ..color = const Color(0x26315DB7)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.25),
      60,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.72),
      92,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

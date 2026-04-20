import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/route_result.dart';

class RouteLayer extends StatelessWidget {
  const RouteLayer({
    super.key,
    required this.route,
    this.isStarted = false,
  });

  final RouteResult? route;
  final bool isStarted;

  @override
  Widget build(BuildContext context) {
    final currentRoute = route;
    if (currentRoute == null || currentRoute.polylinePoints.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        if (isStarted)
          Polyline(
            points: currentRoute.polylinePoints,
            strokeWidth: 8,
            color: Colors.white,
          ),
        Polyline(
          points: currentRoute.polylinePoints,
          strokeWidth: 4,
          color: isStarted ? const Color(0xFF2196F3) : const Color(0xFF1B8A5A),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/realtime_driver_marker.dart';
import 'animated_driver_marker.dart';

class DriversLayer extends StatelessWidget {
  const DriversLayer({
    super.key,
    required this.drivers,
  });

  final List<RealtimeDriverMarker> drivers;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final driver in drivers.take(8))
          Marker(
            point: LatLng(
              driver.position.latitude,
              driver.position.longitude,
            ),
            width: 50,
            height: 50,
            child: AnimatedDriverMarker(
              key: ValueKey('driver-${driver.driverId}'),
              position: LatLng(
                driver.position.latitude,
                driver.position.longitude,
              ),
            ),
          ),
      ],
    );
  }
}

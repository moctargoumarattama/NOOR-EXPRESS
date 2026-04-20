import 'package:latlong2/latlong.dart';

class RouteResult {
  const RouteResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['polyline'];
    final points = rawPoints is List
        ? rawPoints
            .whereType<List>()
            .map(
              (point) => LatLng(
                (point[0] as num?)?.toDouble() ?? 0,
                (point[1] as num?)?.toDouble() ?? 0,
              ),
            )
            .where((point) => point.latitude != 0 || point.longitude != 0)
            .toList()
        : <LatLng>[];

    return RouteResult(
      polylinePoints: points,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (json['duration_min'] as num?)?.toInt() ?? 1,
    );
  }

  factory RouteResult.fallback(LatLng origin, LatLng destination) {
    final distance = const Distance().as(
      LengthUnit.Kilometer,
      origin,
      destination,
    );
    return RouteResult(
      polylinePoints: [origin, destination],
      distanceKm: distance,
      durationMinutes: (distance / 25 * 60).clamp(1, 999).round(),
    );
  }
}

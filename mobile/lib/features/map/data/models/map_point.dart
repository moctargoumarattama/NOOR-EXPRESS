class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  MapPoint copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    bool clearAccuracyMeters = false,
  }) {
    return MapPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters:
          clearAccuracyMeters ? null : accuracyMeters ?? this.accuracyMeters,
    );
  }
}

class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  MapPoint copyWith({
    double? latitude,
    double? longitude,
  }) {
    return MapPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

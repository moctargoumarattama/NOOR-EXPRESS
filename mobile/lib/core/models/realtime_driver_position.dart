class RealtimeDriverPosition {
  const RealtimeDriverPosition({
    required this.driverId,
    required this.latitude,
    required this.longitude,
  });

  final int driverId;
  final double latitude;
  final double longitude;

  factory RealtimeDriverPosition.fromJson(Map<String, dynamic> json) {
    return RealtimeDriverPosition(
      driverId: json['driver_id'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

import '../../../../core/models/realtime_driver_position.dart';
import 'map_point.dart';

class RealtimeDriverMarker {
  const RealtimeDriverMarker({
    required this.driverId,
    required this.position,
  });

  final int driverId;
  final MapPoint position;

  factory RealtimeDriverMarker.fromJson(Map<String, dynamic> json) {
    return RealtimeDriverMarker(
      driverId: json['driver_id'] as int? ?? 0,
      position: MapPoint(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  factory RealtimeDriverMarker.fromRealtimePosition(
    RealtimeDriverPosition value,
  ) {
    return RealtimeDriverMarker(
      driverId: value.driverId,
      position: MapPoint(
        latitude: value.latitude,
        longitude: value.longitude,
      ),
    );
  }

  RealtimeDriverMarker copyWith({
    int? driverId,
    MapPoint? position,
  }) {
    return RealtimeDriverMarker(
      driverId: driverId ?? this.driverId,
      position: position ?? this.position,
    );
  }
}

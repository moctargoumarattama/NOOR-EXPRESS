import '../../../../core/location/location_quality.dart';

class AddressResult {
  const AddressResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.locationQuality,
    this.accuracyMeters,
  });

  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;
  final LocationQuality? locationQuality;
  final double? accuracyMeters;

  bool get isKnownZone => type == 'zone';
  bool get isCurrentLocation => type == 'current_location';

  AddressResult copyWith({
    String? name,
    String? displayName,
    double? latitude,
    double? longitude,
    String? type,
    LocationQuality? locationQuality,
    double? accuracyMeters,
    bool clearAccuracyMeters = false,
  }) {
    return AddressResult(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      locationQuality: locationQuality ?? this.locationQuality,
      accuracyMeters:
          clearAccuracyMeters ? null : accuracyMeters ?? this.accuracyMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'lat': latitude,
      'lon': longitude,
      'type': type,
      if (locationQuality != null) 'location_quality': locationQuality!.name,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
    };
  }
}

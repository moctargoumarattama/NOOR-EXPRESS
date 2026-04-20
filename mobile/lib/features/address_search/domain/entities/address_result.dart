class AddressResult {
  const AddressResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;

  bool get isKnownZone => type == 'zone';
  bool get isCurrentLocation => type == 'current_location';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'lat': latitude,
      'lon': longitude,
      'type': type,
    };
  }
}

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.profilePhoto,
    required this.driverStatus,
    required this.pauseStartedAt,
    required this.isAvailable,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.plateNumber,
    required this.maxRadiusKm,
  });

  final int id;
  final String phoneNumber;
  final String? name;
  final String? profilePhoto;
  final String? driverStatus;
  final DateTime? pauseStartedAt;
  final bool isAvailable;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? plateNumber;
  final int maxRadiusKm;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as int? ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      name: json['name'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      driverStatus: json['driver_status'] as String?,
      pauseStartedAt: _parsePauseStartedAt(json['pause_started_at']),
      isAvailable: json['is_available'] as bool? ?? false,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      plateNumber: json['plate_number'] as String?,
      maxRadiusKm: _parseMaxRadiusKm(json['max_radius_km']),
    );
  }

  DriverProfile copyWith({
    int? id,
    String? phoneNumber,
    String? name,
    String? profilePhoto,
    String? driverStatus,
    DateTime? pauseStartedAt,
    bool? isAvailable,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? plateNumber,
    int? maxRadiusKm,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      driverStatus: driverStatus ?? this.driverStatus,
      pauseStartedAt: pauseStartedAt ?? this.pauseStartedAt,
      isAvailable: isAvailable ?? this.isAvailable,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      plateNumber: plateNumber ?? this.plateNumber,
      maxRadiusKm: maxRadiusKm ?? this.maxRadiusKm,
    );
  }
}

int _parseMaxRadiusKm(Object? value) {
  final parsed = (value as num?)?.toInt() ?? 5;
  if (parsed < 1) {
    return 1;
  }
  if (parsed > 10) {
    return 10;
  }
  return parsed;
}

DateTime? _parsePauseStartedAt(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

class DriverProfileUpdateInput {
  const DriverProfileUpdateInput({
    this.name,
    this.profilePhoto,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.plateNumber,
  });

  final String? name;
  final String? profilePhoto;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? plateNumber;

  Map<String, dynamic> toJson() {
    final payload = {
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'vehicle_color': vehicleColor,
      'plate_number': plateNumber,
    };
    if (name != null) {
      payload['name'] = name;
    }
    if (profilePhoto != null) {
      payload['profile_photo'] = profilePhoto;
    }
    return payload;
  }
}

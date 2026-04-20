class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.profilePhoto,
    required this.driverStatus,
    required this.isAvailable,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.plateNumber,
  });

  final int id;
  final String phoneNumber;
  final String? name;
  final String? profilePhoto;
  final String? driverStatus;
  final bool isAvailable;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? plateNumber;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as int? ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      name: json['name'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      driverStatus: json['driver_status'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      plateNumber: json['plate_number'] as String?,
    );
  }

  DriverProfile copyWith({
    int? id,
    String? phoneNumber,
    String? name,
    String? profilePhoto,
    String? driverStatus,
    bool? isAvailable,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? plateNumber,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      driverStatus: driverStatus ?? this.driverStatus,
      isAvailable: isAvailable ?? this.isAvailable,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      plateNumber: plateNumber ?? this.plateNumber,
    );
  }
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

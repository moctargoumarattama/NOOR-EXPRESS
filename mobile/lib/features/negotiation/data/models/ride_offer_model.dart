class NegotiationRideModel {
  const NegotiationRideModel({
    required this.rideId,
    required this.pickup,
    required this.dropoff,
    required this.clientPrice,
    required this.status,
    this.distanceKm,
  });

  final int rideId;
  final String pickup;
  final String dropoff;
  final double clientPrice;
  final String status;
  final double? distanceKm;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  NegotiationRideModel copyWith({
    int? rideId,
    String? pickup,
    String? dropoff,
    double? clientPrice,
    String? status,
    double? distanceKm,
  }) {
    return NegotiationRideModel(
      rideId: rideId ?? this.rideId,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      clientPrice: clientPrice ?? this.clientPrice,
      status: status ?? this.status,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  factory NegotiationRideModel.fromRideRequestJson(Map<String, dynamic> json) {
    return NegotiationRideModel(
      rideId: (json['id'] as num?)?.toInt() ?? 0,
      pickup: json['pickup_location'] as String? ?? '',
      dropoff: json['dropoff_location'] as String? ?? '',
      clientPrice: _asDouble(json['estimated_price']),
      status: json['status'] as String? ?? 'pending',
      distanceKm: _asNullableDouble(json['distance_km']),
    );
  }

  factory NegotiationRideModel.fromDriverNotificationJson(
    Map<String, dynamic> json,
  ) {
    return NegotiationRideModel(
      rideId:
          ((json['ride_id'] ?? json['ride_request_id']) as num?)?.toInt() ?? 0,
      pickup: (json['pickup'] ?? json['pickup_location']) as String? ?? '',
      dropoff: (json['dropoff'] ?? json['dropoff_location']) as String? ?? '',
      clientPrice: _asDouble(json['client_price']),
      status: 'pending',
      distanceKm: _asNullableDouble(json['distance_km']),
    );
  }
}

class RideOfferModel {
  const RideOfferModel({
    required this.offerId,
    required this.driverId,
    required this.driverName,
    required this.driverRating,
    required this.proposedPrice,
    required this.status,
    this.driverDistanceKm,
    this.driverEtaMinutes,
    this.driverCompletedRides = 0,
    this.isDriverVerified = false,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.plateNumber,
    this.vehiclePhoto,
  });

  final int offerId;
  final int driverId;
  final String driverName;
  final double driverRating;
  final double proposedPrice;
  final String status;
  final double? driverDistanceKm;
  final int? driverEtaMinutes;
  final int driverCompletedRides;
  final bool isDriverVerified;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? plateNumber;
  final String? vehiclePhoto;

  String get vehicleLabel {
    final parts = [
      vehicleBrand,
      vehicleModel,
      vehicleColor,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Vehicule a confirmer' : parts.join(' ');
  }

  factory RideOfferModel.fromJson(Map<String, dynamic> json) {
    return RideOfferModel(
      offerId: ((json['offer_id'] ?? json['id']) as num?)?.toInt() ?? 0,
      driverId: (json['driver_id'] as num?)?.toInt() ?? 0,
      driverName: json['driver_name'] as String? ?? 'Driver',
      driverRating: _asDouble(json['driver_rating']),
      proposedPrice: _asDouble(json['proposed_price']),
      status: json['status'] as String? ?? 'pending',
      driverDistanceKm: _asNullableDouble(json['driver_distance_km']),
      driverEtaMinutes: _asNullableInt(
        json['driver_eta_minutes'] ??
            json['driver_eta_min'] ??
            json['eta_minutes'] ??
            json['eta_min'],
      ),
      driverCompletedRides: _asNullableInt(json['driver_completed_rides']) ?? 0,
      isDriverVerified: json['driver_verified'] == true,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      plateNumber: json['plate_number'] as String?,
      vehiclePhoto: json['vehicle_photo'] as String?,
    );
  }

  factory RideOfferModel.fromWebSocketJson(Map<String, dynamic> json) {
    return RideOfferModel(
      offerId: (json['offer_id'] as num?)?.toInt() ?? 0,
      driverId: (json['driver_id'] as num?)?.toInt() ?? 0,
      driverName: json['driver_name'] as String? ?? 'Driver',
      driverRating: _asDouble(json['driver_rating']),
      proposedPrice: _asDouble(json['proposed_price']),
      status: 'pending',
      driverDistanceKm: _asNullableDouble(json['driver_distance_km']),
      driverEtaMinutes: _asNullableInt(
        json['driver_eta_minutes'] ??
            json['driver_eta_min'] ??
            json['eta_minutes'] ??
            json['eta_min'],
      ),
      driverCompletedRides: _asNullableInt(json['driver_completed_rides']) ?? 0,
      isDriverVerified: json['driver_verified'] == true,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      plateNumber: json['plate_number'] as String?,
      vehiclePhoto: json['vehicle_photo'] as String?,
    );
  }
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class DriverRide {
  const DriverRide({
    required this.id,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.status,
    required this.estimatedPrice,
    required this.createdAt,
    this.agreedPrice,
    this.finalPrice,
    this.driverNetEarnings,
    this.distanceToPickupKm,
  });

  final int id;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final double estimatedPrice;
  final double? agreedPrice;
  final double? finalPrice;
  final double? driverNetEarnings;
  final double? distanceToPickupKm;
  final DateTime createdAt;

  double get displayPrice => finalPrice ?? agreedPrice ?? estimatedPrice;

  factory DriverRide.fromJson(Map<String, dynamic> json) {
    return DriverRide(
      id: json['id'] as int? ?? 0,
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropoffLocation: json['dropoff_location'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      driverNetEarnings: (json['driver_net_earnings'] as num?)?.toDouble(),
      distanceToPickupKm: _asNullableDouble(json['driver_distance_km']),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  DriverRide copyWith({
    int? id,
    String? pickupLocation,
    String? dropoffLocation,
    String? status,
    double? estimatedPrice,
    double? agreedPrice,
    double? finalPrice,
    double? driverNetEarnings,
    double? distanceToPickupKm,
    DateTime? createdAt,
  }) {
    return DriverRide(
      id: id ?? this.id,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      status: status ?? this.status,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      driverNetEarnings: driverNetEarnings ?? this.driverNetEarnings,
      distanceToPickupKm: distanceToPickupKm ?? this.distanceToPickupKm,
      createdAt: createdAt ?? this.createdAt,
    );
  }
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

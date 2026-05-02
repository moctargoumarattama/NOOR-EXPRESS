class DriverRide {
  const DriverRide({
    required this.id,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.status,
    required this.estimatedPrice,
    required this.createdAt,
    this.distanceKm,
    this.durationMinutes,
    this.agreedPrice,
    this.finalPrice,
    this.platformCommission,
    this.driverNetEarnings,
    this.ratingFromClient,
    this.completedAt,
    this.distanceToPickupKm,
  });

  final int id;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final double estimatedPrice;
  final double? distanceKm;
  final int? durationMinutes;
  final double? agreedPrice;
  final double? finalPrice;
  final double? platformCommission;
  final double? driverNetEarnings;
  final double? ratingFromClient;
  final DateTime? completedAt;
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
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      platformCommission: (json['platform_commission'] as num?)?.toDouble(),
      driverNetEarnings: (json['driver_net_earnings'] as num?)?.toDouble(),
      ratingFromClient:
          (json['client_rating_for_driver'] as num?)?.toDouble(),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '')
          ?.toLocal(),
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
    double? distanceKm,
    int? durationMinutes,
    double? agreedPrice,
    double? finalPrice,
    double? platformCommission,
    double? driverNetEarnings,
    double? ratingFromClient,
    DateTime? completedAt,
    double? distanceToPickupKm,
    DateTime? createdAt,
  }) {
    return DriverRide(
      id: id ?? this.id,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      status: status ?? this.status,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      platformCommission: platformCommission ?? this.platformCommission,
      driverNetEarnings: driverNetEarnings ?? this.driverNetEarnings,
      ratingFromClient: ratingFromClient ?? this.ratingFromClient,
      completedAt: completedAt ?? this.completedAt,
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

class ClientRide {
  const ClientRide({
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
    this.clientRatingForDriver,
    this.completedAt,
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
  final double? clientRatingForDriver;
  final DateTime createdAt;
  final DateTime? completedAt;

  double get displayPrice => finalPrice ?? agreedPrice ?? estimatedPrice;

  factory ClientRide.fromJson(Map<String, dynamic> json) {
    return ClientRide(
      id: json['id'] as int,
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropoffLocation: json['dropoff_location'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      clientRatingForDriver:
          (json['client_rating_for_driver'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      completedAt:
          DateTime.tryParse(json['completed_at'] as String? ?? '')?.toLocal(),
    );
  }

  ClientRide copyWith({
    int? id,
    String? pickupLocation,
    String? dropoffLocation,
    String? status,
    double? estimatedPrice,
    double? distanceKm,
    int? durationMinutes,
    double? agreedPrice,
    double? finalPrice,
    double? clientRatingForDriver,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ClientRide(
      id: id ?? this.id,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      status: status ?? this.status,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      clientRatingForDriver:
          clientRatingForDriver ?? this.clientRatingForDriver,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class RideRequestCreateInput {
  const RideRequestCreateInput({
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.clientLatitude,
    required this.clientLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    this.estimatedPrice,
  });

  final String pickupLocation;
  final String dropoffLocation;
  final double clientLatitude;
  final double clientLongitude;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final double? estimatedPrice;

  Map<String, dynamic> toJson() {
    final payload = {
      'pickup_location': pickupLocation,
      'dropoff_location': dropoffLocation,
      'client_latitude': clientLatitude,
      'client_longitude': clientLongitude,
      'dropoff_latitude': dropoffLatitude,
      'dropoff_longitude': dropoffLongitude,
    };
    if (estimatedPrice != null) {
      payload['estimated_price'] = estimatedPrice!;
    }
    return payload;
  }
}

class PriceEstimate {
  const PriceEstimate({
    required this.estimatedPrice,
    required this.distanceKm,
    this.durationMin,
    this.pickupZone,
    this.dropoffZone,
    this.minPrice,
    this.maxPrice,
    this.availableDriversCount,
    this.searchRadiusKm,
  });

  final double estimatedPrice;
  final double distanceKm;
  final int? durationMin;
  final String? pickupZone;
  final String? dropoffZone;
  final double? minPrice;
  final double? maxPrice;
  final int? availableDriversCount;
  final double? searchRadiusKm;

  factory PriceEstimate.fromJson(Map<String, dynamic> json) {
    return PriceEstimate(
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toInt(),
      pickupZone: json['pickup_zone'] as String?,
      dropoffZone: json['dropoff_zone'] as String?,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      availableDriversCount: (json['available_drivers_count'] as num?)?.toInt(),
      searchRadiusKm: (json['search_radius_km'] as num?)?.toDouble(),
    );
  }
}

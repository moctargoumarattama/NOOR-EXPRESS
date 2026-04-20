class ClientRide {
  const ClientRide({
    required this.id,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.status,
    required this.estimatedPrice,
    required this.createdAt,
    this.finalPrice,
  });

  final int id;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final double estimatedPrice;
  final double? finalPrice;
  final DateTime createdAt;

  factory ClientRide.fromJson(Map<String, dynamic> json) {
    return ClientRide(
      id: json['id'] as int,
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropoffLocation: json['dropoff_location'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  ClientRide copyWith({
    int? id,
    String? pickupLocation,
    String? dropoffLocation,
    String? status,
    double? estimatedPrice,
    double? finalPrice,
    DateTime? createdAt,
  }) {
    return ClientRide(
      id: id ?? this.id,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      status: status ?? this.status,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      createdAt: createdAt ?? this.createdAt,
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
    this.pickupZone,
    this.dropoffZone,
  });

  final double estimatedPrice;
  final double distanceKm;
  final String? pickupZone;
  final String? dropoffZone;

  factory PriceEstimate.fromJson(Map<String, dynamic> json) {
    return PriceEstimate(
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      pickupZone: json['pickup_zone'] as String?,
      dropoffZone: json['dropoff_zone'] as String?,
    );
  }
}

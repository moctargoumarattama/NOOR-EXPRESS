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
  });

  final int id;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final double estimatedPrice;
  final double? agreedPrice;
  final double? finalPrice;
  final double? driverNetEarnings;
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

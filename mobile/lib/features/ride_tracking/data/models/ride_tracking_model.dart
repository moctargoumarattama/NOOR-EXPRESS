enum RideTrackingStatus {
  pending,
  accepted,
  arrived,
  started,
  completed,
  cancelled,
  expired,
  unknown,
}

class TrackingCoordinates {
  const TrackingCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  factory TrackingCoordinates.fromJson(
    Map<String, dynamic> json, {
    required String latitudeKey,
    required String longitudeKey,
  }) {
    return TrackingCoordinates(
      latitude: (json[latitudeKey] as num).toDouble(),
      longitude: (json[longitudeKey] as num).toDouble(),
    );
  }
}

class TrackingCounterpartModel {
  const TrackingCounterpartModel({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.rating,
    this.plateNumber,
    this.vehicleLabel,
  });

  final int id;
  final String displayName;
  final String phoneNumber;
  final double? rating;
  final String? plateNumber;
  final String? vehicleLabel;

  String get avatarLabel {
    final sanitized = displayName.replaceAll('+', '').replaceAll(' ', '');
    if (sanitized.length >= 2) {
      return sanitized.substring(sanitized.length - 2).toUpperCase();
    }
    return sanitized.toUpperCase();
  }

  factory TrackingCounterpartModel.fromUserJson(
    Map<String, dynamic> json, {
    double? rating,
  }) {
    final phoneNumber = json['phone_number'] as String? ?? 'Utilisateur';
    final brand = json['vehicle_brand'] as String?;
    final model = json['vehicle_model'] as String?;
    final color = json['vehicle_color'] as String?;

    final vehicleParts = [brand, model, color]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();

    return TrackingCounterpartModel(
      id: json['id'] as int? ?? 0,
      displayName: phoneNumber,
      phoneNumber: phoneNumber,
      rating: rating,
      plateNumber: json['plate_number'] as String?,
      vehicleLabel: vehicleParts.isEmpty ? null : vehicleParts.join(' • '),
    );
  }
}

class RideTrackingModel {
  const RideTrackingModel({
    required this.id,
    required this.clientId,
    required this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.estimatedPrice,
    required this.createdAt,
    required this.status,
    this.pickupPosition,
    this.dropoffPosition,
    this.finalPrice,
    this.driverNetEarnings,
    this.cancellationReason,
    this.clientRatingForDriver,
  });

  final int id;
  final int clientId;
  final int? driverId;
  final String pickupLocation;
  final String dropoffLocation;
  final double estimatedPrice;
  final DateTime createdAt;
  final RideTrackingStatus status;
  final TrackingCoordinates? pickupPosition;
  final TrackingCoordinates? dropoffPosition;
  final double? finalPrice;
  final double? driverNetEarnings;
  final String? cancellationReason;
  final double? clientRatingForDriver;

  bool get hasDriver => driverId != null;
  bool get isPending => status == RideTrackingStatus.pending;
  bool get isAccepted => status == RideTrackingStatus.accepted;
  bool get isArrived => status == RideTrackingStatus.arrived;
  bool get isStarted => status == RideTrackingStatus.started;
  bool get isCompleted => status == RideTrackingStatus.completed;
  bool get canClientCancel =>
      status == RideTrackingStatus.pending ||
      status == RideTrackingStatus.accepted;
  bool get canRateDriver =>
      status == RideTrackingStatus.completed && clientRatingForDriver == null;

  double get displayedPrice => finalPrice ?? estimatedPrice;

  factory RideTrackingModel.fromJson(Map<String, dynamic> json) {
    return RideTrackingModel(
      id: json['id'] as int? ?? 0,
      clientId: json['client_id'] as int? ?? 0,
      driverId: json['driver_id'] as int?,
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropoffLocation: json['dropoff_location'] as String? ?? '',
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: fromRawStatus(json['status'] as String?),
      pickupPosition: _readCoordinates(
        json,
        latitudeKey: 'pickup_latitude',
        longitudeKey: 'pickup_longitude',
      ),
      dropoffPosition: _readCoordinates(
        json,
        latitudeKey: 'dropoff_latitude',
        longitudeKey: 'dropoff_longitude',
      ),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      driverNetEarnings: (json['driver_net_earnings'] as num?)?.toDouble(),
      cancellationReason: json['cancellation_reason'] as String?,
      clientRatingForDriver: (json['client_rating_for_driver'] as num?)?.toDouble(),
    );
  }

  RideTrackingModel copyWith({
    int? driverId,
    RideTrackingStatus? status,
    TrackingCoordinates? pickupPosition,
    TrackingCoordinates? dropoffPosition,
    double? finalPrice,
    double? driverNetEarnings,
    String? cancellationReason,
    double? clientRatingForDriver,
  }) {
    return RideTrackingModel(
      id: id,
      clientId: clientId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      estimatedPrice: estimatedPrice,
      createdAt: createdAt,
      status: status ?? this.status,
      pickupPosition: pickupPosition ?? this.pickupPosition,
      dropoffPosition: dropoffPosition ?? this.dropoffPosition,
      finalPrice: finalPrice ?? this.finalPrice,
      driverNetEarnings: driverNetEarnings ?? this.driverNetEarnings,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      clientRatingForDriver:
          clientRatingForDriver ?? this.clientRatingForDriver,
    );
  }

  static RideTrackingStatus fromRawStatus(String? value) {
    switch (value) {
      case 'pending':
        return RideTrackingStatus.pending;
      case 'accepted':
        return RideTrackingStatus.accepted;
      case 'arrived':
        return RideTrackingStatus.arrived;
      case 'started':
        return RideTrackingStatus.started;
      case 'completed':
        return RideTrackingStatus.completed;
      case 'cancelled':
        return RideTrackingStatus.cancelled;
      case 'expired':
        return RideTrackingStatus.expired;
      default:
        return RideTrackingStatus.unknown;
    }
  }

  static TrackingCoordinates? _readCoordinates(
    Map<String, dynamic> json, {
    required String latitudeKey,
    required String longitudeKey,
  }) {
    final latitude = json[latitudeKey] as num?;
    final longitude = json[longitudeKey] as num?;
    if (latitude == null || longitude == null) {
      return null;
    }

    return TrackingCoordinates(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}

enum RideTrackingStatus {
  pending,
  offered,
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
    final rawName = json['name'] as String?;
    final phoneNumber = json['phone_number'] as String? ?? 'Utilisateur';
    final brand = json['vehicle_brand'] as String?;
    final model = json['vehicle_model'] as String?;
    final color = json['vehicle_color'] as String?;
    final displayName =
        rawName == null || rawName.trim().isEmpty ? phoneNumber : rawName.trim();

    final vehicleParts = [brand, model, color]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();

    return TrackingCounterpartModel(
      id: json['id'] as int? ?? 0,
      displayName: displayName,
      phoneNumber: phoneNumber,
      rating: rating,
      plateNumber: json['plate_number'] as String?,
      vehicleLabel: vehicleParts.isEmpty ? null : vehicleParts.join(' - '),
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
    this.distanceKm,
    this.durationMinutes,
    this.agreedPrice,
    this.finalPrice,
    this.platformCommission,
    this.driverNetEarnings,
    this.cancellationReason,
    this.clientRatingForDriver,
    this.completedAt,
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
  final double? distanceKm;
  final int? durationMinutes;
  final double? agreedPrice;
  final double? finalPrice;
  final double? platformCommission;
  final double? driverNetEarnings;
  final String? cancellationReason;
  final double? clientRatingForDriver;
  final DateTime? completedAt;

  bool get hasDriver => driverId != null;
  bool get isPending => status == RideTrackingStatus.pending;
  bool get isOffered => status == RideTrackingStatus.offered;
  bool get isAccepted => status == RideTrackingStatus.accepted;
  bool get isArrived => status == RideTrackingStatus.arrived;
  bool get isStarted => status == RideTrackingStatus.started;
  bool get isCompleted => status == RideTrackingStatus.completed;
  bool get canUseChat =>
      status == RideTrackingStatus.accepted ||
      status == RideTrackingStatus.arrived ||
      status == RideTrackingStatus.started;
  bool get canClientCancel =>
      status == RideTrackingStatus.pending ||
      status == RideTrackingStatus.offered ||
      status == RideTrackingStatus.accepted;
  bool get canDriverCancel =>
      status == RideTrackingStatus.accepted ||
      status == RideTrackingStatus.arrived;
  bool get canRateDriver =>
      status == RideTrackingStatus.completed && clientRatingForDriver == null;

  double get displayedPrice => finalPrice ?? agreedPrice ?? estimatedPrice;

  factory RideTrackingModel.fromJson(Map<String, dynamic> json) {
    return RideTrackingModel(
      id: json['id'] as int? ?? 0,
      clientId: json['client_id'] as int? ?? 0,
      driverId: json['driver_id'] as int?,
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropoffLocation: json['dropoff_location'] as String? ?? '',
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
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
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      platformCommission: (json['platform_commission'] as num?)?.toDouble(),
      driverNetEarnings: (json['driver_net_earnings'] as num?)?.toDouble(),
      cancellationReason: json['cancellation_reason'] as String?,
      clientRatingForDriver:
          (json['client_rating_for_driver'] as num?)?.toDouble(),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '')
          ?.toLocal(),
    );
  }

  RideTrackingModel copyWith({
    int? driverId,
    RideTrackingStatus? status,
    TrackingCoordinates? pickupPosition,
    TrackingCoordinates? dropoffPosition,
    double? distanceKm,
    int? durationMinutes,
    double? agreedPrice,
    double? finalPrice,
    double? platformCommission,
    double? driverNetEarnings,
    String? cancellationReason,
    double? clientRatingForDriver,
    DateTime? completedAt,
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
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      platformCommission: platformCommission ?? this.platformCommission,
      driverNetEarnings: driverNetEarnings ?? this.driverNetEarnings,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      clientRatingForDriver:
          clientRatingForDriver ?? this.clientRatingForDriver,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static RideTrackingStatus fromRawStatus(String? value) {
    switch (value) {
      case 'pending':
        return RideTrackingStatus.pending;
      case 'offered':
        return RideTrackingStatus.offered;
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

class RideChatMessageModel {
  const RideChatMessageModel({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int rideId;
  final int senderId;
  final String senderRole;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  bool isMine(int currentUserId) => senderId == currentUserId;

  factory RideChatMessageModel.fromJson(Map<String, dynamic> json) {
    return RideChatMessageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rideId: ((json['ride_id'] ?? json['rideId']) as num?)?.toInt() ?? 0,
      senderId:
          ((json['sender_id'] ?? json['senderId']) as num?)?.toInt() ?? 0,
      senderRole: json['sender_role'] as String? ?? '',
      content: (json['content'] as String? ?? '').trim(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  RideChatMessageModel copyWith({
    bool? isRead,
  }) {
    return RideChatMessageModel(
      id: id,
      rideId: rideId,
      senderId: senderId,
      senderRole: senderRole,
      content: content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class RideChatPageModel {
  const RideChatPageModel({
    required this.items,
    required this.unreadCount,
    required this.limit,
    required this.offset,
  });

  final List<RideChatMessageModel> items;
  final int unreadCount;
  final int limit;
  final int offset;

  factory RideChatPageModel.fromJson(Map<String, dynamic> json) {
    return RideChatPageModel(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => RideChatMessageModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

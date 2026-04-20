class ClientProfileModel {
  const ClientProfileModel({
    required this.id,
    required this.phoneNumber,
    required this.totalRides,
    required this.averageRating,
    required this.createdAt,
    this.name,
    this.profilePhoto,
  });

  final int id;
  final String? name;
  final String phoneNumber;
  final String? profilePhoto;
  final DateTime createdAt;
  final int totalRides;
  final double averageRating;

  String get displayName {
    final cleaned = name?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      return cleaned;
    }
    return 'Client Noor';
  }

  String get initials {
    final words =
        displayName.split(' ').where((word) => word.trim().isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words.first[0]}${words[1][0]}'.toUpperCase();
    }
    final safeName = displayName.isEmpty ? 'C' : displayName;
    return safeName.substring(0, safeName.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory ClientProfileModel.fromJson(Map<String, dynamic> json) {
    return ClientProfileModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      phoneNumber: json['phone_number'] as String? ?? '',
      profilePhoto: json['profile_photo'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      totalRides: json['total_rides'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ClientProfileRideModel {
  const ClientProfileRideModel({
    required this.id,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.status,
    required this.createdAt,
    required this.estimatedPrice,
    this.finalPrice,
  });

  final int id;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final DateTime createdAt;
  final double estimatedPrice;
  final double? finalPrice;

  double get displayPrice => finalPrice ?? estimatedPrice;

  factory ClientProfileRideModel.fromJson(Map<String, dynamic> json) {
    return ClientProfileRideModel(
      id: json['id'] as int? ?? 0,
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropoffLocation: json['dropoff_location'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      finalPrice: (json['final_price'] as num?)?.toDouble(),
    );
  }
}

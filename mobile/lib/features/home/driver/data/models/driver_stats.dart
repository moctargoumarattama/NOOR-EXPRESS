class DriverStats {
  const DriverStats({
    required this.totalRides,
    required this.completed,
    required this.started,
    required this.cancelled,
    required this.totalEarnings,
    required this.totalNetEarnings,
    required this.averageCompletedPrice,
    required this.averageRatingFromClients,
    required this.totalRatingsFromClients,
  });

  final int totalRides;
  final int completed;
  final int started;
  final int cancelled;
  final double totalEarnings;
  final double totalNetEarnings;
  final double averageCompletedPrice;
  final double averageRatingFromClients;
  final int totalRatingsFromClients;

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      started: (json['started'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
      totalNetEarnings: (json['total_net_earnings'] as num?)?.toDouble() ?? 0,
      averageCompletedPrice:
          (json['average_completed_price'] as num?)?.toDouble() ?? 0,
      averageRatingFromClients:
          (json['average_rating_from_clients'] as num?)?.toDouble() ?? 0,
      totalRatingsFromClients:
          (json['total_ratings_from_clients'] as num?)?.toInt() ?? 0,
    );
  }
}

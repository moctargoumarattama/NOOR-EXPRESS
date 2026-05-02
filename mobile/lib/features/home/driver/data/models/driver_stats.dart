class DriverRevenueStats {
  const DriverRevenueStats({
    required this.today,
    required this.week,
    required this.month,
    required this.total,
  });

  final double today;
  final double week;
  final double month;
  final double total;

  factory DriverRevenueStats.fromJson(Map<String, dynamic> json) {
    return DriverRevenueStats(
      today: (json['today'] as num?)?.toDouble() ?? 0,
      week: (json['week'] as num?)?.toDouble() ?? 0,
      month: (json['month'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DriverRideStatusStats {
  const DriverRideStatusStats({
    required this.completed,
    required this.cancelled,
    required this.refused,
  });

  final int completed;
  final int cancelled;
  final int refused;

  factory DriverRideStatusStats.fromJson(Map<String, dynamic> json) {
    return DriverRideStatusStats(
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      refused: (json['refused'] as num?)?.toInt() ?? 0,
    );
  }
}

class DriverPeakHourStat {
  const DriverPeakHourStat({
    required this.hour,
    required this.completedRides,
    required this.averageRevenue,
  });

  final int hour;
  final int completedRides;
  final double averageRevenue;

  factory DriverPeakHourStat.fromJson(Map<String, dynamic> json) {
    return DriverPeakHourStat(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      completedRides: (json['completed_rides'] as num?)?.toInt() ?? 0,
      averageRevenue: (json['average_revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DriverProfitableZoneStat {
  const DriverProfitableZoneStat({
    required this.zoneName,
    required this.ridesCount,
    required this.averageRevenue,
  });

  final String zoneName;
  final int ridesCount;
  final double averageRevenue;

  factory DriverProfitableZoneStat.fromJson(Map<String, dynamic> json) {
    return DriverProfitableZoneStat(
      zoneName: (json['zone_name'] as String? ?? '').trim(),
      ridesCount: (json['rides_count'] as num?)?.toInt() ?? 0,
      averageRevenue: (json['average_revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DriverReputationStats {
  const DriverReputationStats({
    required this.last30Days,
    required this.globalAverage,
  });

  final double last30Days;
  final double globalAverage;

  factory DriverReputationStats.fromJson(Map<String, dynamic> json) {
    return DriverReputationStats(
      last30Days: (json['last_30_days'] as num?)?.toDouble() ?? 0,
      globalAverage: (json['global_average'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DriverStats {
  const DriverStats({
    required this.driverId,
    required this.revenue,
    required this.rides,
    required this.peakHours,
    required this.profitableZones,
    required this.reputation,
  });

  final int driverId;
  final DriverRevenueStats revenue;
  final DriverRideStatusStats rides;
  final List<DriverPeakHourStat> peakHours;
  final List<DriverProfitableZoneStat> profitableZones;
  final DriverReputationStats reputation;

  int get totalRides => rides.completed + rides.cancelled + rides.refused;
  int get completed => rides.completed;
  int get started => 0;
  int get cancelled => rides.cancelled;
  double get totalEarnings => revenue.total;
  double get totalNetEarnings => revenue.total;
  double get averageCompletedPrice => 0;
  double get averageRatingFromClients => reputation.globalAverage;
  int get totalRatingsFromClients => 0;

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    final peakHours = (json['peak_hours'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => DriverPeakHourStat.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final normalizedPeakHours = _normalizePeakHours(peakHours);

    return DriverStats(
      driverId: (json['driver_id'] as num?)?.toInt() ?? 0,
      revenue: DriverRevenueStats.fromJson(
        Map<String, dynamic>.from(json['revenue'] as Map? ?? const {}),
      ),
      rides: DriverRideStatusStats.fromJson(
        Map<String, dynamic>.from(json['rides'] as Map? ?? const {}),
      ),
      peakHours: normalizedPeakHours,
      profitableZones: (json['profitable_zones'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => DriverProfitableZoneStat.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      reputation: DriverReputationStats.fromJson(
        Map<String, dynamic>.from(json['reputation'] as Map? ?? const {}),
      ),
    );
  }

  static List<DriverPeakHourStat> _normalizePeakHours(
    List<DriverPeakHourStat> source,
  ) {
    final byHour = {for (final item in source) item.hour: item};
    return List<DriverPeakHourStat>.generate(
      24,
      (hour) =>
          byHour[hour] ??
          DriverPeakHourStat(hour: hour, completedRides: 0, averageRevenue: 0),
      growable: false,
    );
  }
}

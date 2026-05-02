class EarningsWindowModel {
  const EarningsWindowModel({
    required this.ridesCount,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
  });

  final int ridesCount;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;

  factory EarningsWindowModel.fromJson(Map<String, dynamic> json) {
    return EarningsWindowModel(
      ridesCount: (json['rides_count'] as num?)?.toInt() ?? 0,
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DriverWalletSummary {
  const DriverWalletSummary({
    required this.driverId,
    required this.today,
    required this.week,
    required this.total,
  });

  final int driverId;
  final EarningsWindowModel today;
  final EarningsWindowModel week;
  final EarningsWindowModel total;

  factory DriverWalletSummary.fromJson(Map<String, dynamic> json) {
    return DriverWalletSummary(
      driverId: (json['driver_id'] as num?)?.toInt() ?? 0,
      today: EarningsWindowModel.fromJson(
        Map<String, dynamic>.from(json['today'] as Map? ?? const {}),
      ),
      week: EarningsWindowModel.fromJson(
        Map<String, dynamic>.from(json['week'] as Map? ?? const {}),
      ),
      total: EarningsWindowModel.fromJson(
        Map<String, dynamic>.from(json['total'] as Map? ?? const {}),
      ),
    );
  }
}

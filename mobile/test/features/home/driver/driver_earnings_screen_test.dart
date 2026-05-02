import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/features/home/driver/data/driver_repository.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_stats.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_wallet_summary.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/screens/driver_earnings_screen.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/screens/driver_stats_screen.dart';

void main() {
  test('DriverStats.fromJson normalizes missing peak hours to 24 items', () {
    final stats = DriverStats.fromJson({
      'driver_id': 7,
      'revenue': {
        'today': 1000,
        'week': 3000,
        'month': 7000,
        'total': 15000,
      },
      'rides': {
        'completed': 2,
        'cancelled': 1,
        'refused': 1,
      },
      'peak_hours': [
        {'hour': 8, 'completed_rides': 2, 'average_revenue': 1800},
      ],
      'profitable_zones': [],
      'reputation': {
        'last_30_days': 4.5,
        'global_average': 4.4,
      },
    });

    expect(stats.peakHours.length, 24);
    expect(stats.peakHours[8].completedRides, 2);
    expect(stats.peakHours[0].completedRides, 0);
  });

  testWidgets('DriverEarningsScreen shows today, week and total summaries',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWith(
            (ref) => _FakeDriverRepository(),
          ),
        ],
        child: const MaterialApp(home: DriverEarningsScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Mes revenus'), findsOneWidget);
    expect(find.text('Aujourd hui'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Depuis inscription'), findsOneWidget);
    expect(find.text('2380 F'), findsOneWidget);
    expect(find.text('10625 F'), findsOneWidget);
    expect(find.text('68425 F'), findsOneWidget);
  });

  testWidgets('DriverStatsScreen shows revenue and zones sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWith(
            (ref) => _FakeDriverRepository(),
          ),
        ],
        child: const MaterialApp(home: DriverStatsScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Mes stats'), findsOneWidget);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Heures de pointe'), findsOneWidget);
    expect(find.text('Zones rentables'), findsOneWidget);
    expect(find.text('2 380 FCFA'), findsOneWidget);
  });
}

class _FakeDriverRepository extends DriverRepository {
  _FakeDriverRepository() : super(apiClient: ApiClient());

  @override
  Future<DriverStats> fetchStats() async {
    return DriverStats.fromJson({
      'driver_id': 9,
      'revenue': {
        'today': 2380,
        'week': 10625,
        'month': 38425,
        'total': 68425,
      },
      'rides': {
        'completed': 28,
        'cancelled': 2,
        'refused': 4,
      },
      'peak_hours': List<Map<String, dynamic>>.generate(
        24,
        (hour) => {
          'hour': hour,
          'completed_rides': hour == 8 ? 4 : 0,
          'average_revenue': hour == 8 ? 2600 : 0,
        },
      ),
      'profitable_zones': [
        {
          'zone_name': 'Plateau',
          'rides_count': 6,
          'average_revenue': 2750,
        },
      ],
      'reputation': {
        'last_30_days': 4.7,
        'global_average': 4.5,
      },
    });
  }

  @override
  Future<DriverWalletSummary> fetchWalletSummary() async {
    return const DriverWalletSummary(
      driverId: 9,
      today: EarningsWindowModel(
        ridesCount: 1,
        grossAmount: 2800,
        commissionAmount: 420,
        netAmount: 2380,
      ),
      week: EarningsWindowModel(
        ridesCount: 4,
        grossAmount: 12500,
        commissionAmount: 1875,
        netAmount: 10625,
      ),
      total: EarningsWindowModel(
        ridesCount: 28,
        grossAmount: 80500,
        commissionAmount: 12075,
        netAmount: 68425,
      ),
    );
  }
}

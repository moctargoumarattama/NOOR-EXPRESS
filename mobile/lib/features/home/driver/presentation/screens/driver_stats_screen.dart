import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/driver_repository.dart';
import '../../data/models/driver_stats.dart';
import '../../data/models/driver_ride.dart';
import '../controllers/ride_driver_controller.dart';
import '../widgets/driver_stats_summary.dart';

class DriverStatsScreen extends ConsumerStatefulWidget {
  const DriverStatsScreen({super.key});

  @override
  ConsumerState<DriverStatsScreen> createState() => _DriverStatsScreenState();
}

class _DriverStatsScreenState extends ConsumerState<DriverStatsScreen> {
  late Future<DriverStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ref.read(driverRepositoryProvider).fetchStats();
    Future.microtask(() => ref.read(rideDriverProvider.notifier).loadRides());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rideDriverProvider);
    final completed = state.rides.where((ride) => ride.status == 'completed');
    final totalEarnings = completed.fold<double>(
      0,
      (sum, ride) => sum + _rideEarning(ride),
    );
    final weekCounts = _weekCounts(state.rides);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mes statistiques',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<DriverStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const DriverStatsErrorCard();
                  }
                  return DriverStatsSummary(stats: snapshot.data);
                },
              ),
              const SizedBox(height: 16),
              _EarningsCard(totalEarnings: totalEarnings),
              const SizedBox(height: 22),
              const Text(
                'Cette semaine',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final day in _days)
                _WeekBar(
                  label: day.label,
                  count: weekCounts[day.index] ?? 0,
                  max: weekCounts.values.fold<int>(1, (a, b) => a > b ? a : b),
                ),
              if (state.isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.historyErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    state.historyErrorMessage!,
                    style: const TextStyle(color: Color(0xFFE53935)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _rideEarning(DriverRide ride) {
    return ride.driverNetEarnings ?? ride.finalPrice ?? ride.estimatedPrice;
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = ref.read(driverRepositoryProvider).fetchStats();
    });
    await ref.read(rideDriverProvider.notifier).loadRides();
  }

  Map<int, int> _weekCounts(List<DriverRide> rides) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final result = <int, int>{};

    for (final ride in rides) {
      final date = ride.createdAt;
      final sameWeek = date.isAfter(
        DateTime(start.year, start.month, start.day),
      );
      if (!sameWeek) {
        continue;
      }
      result[date.weekday] = (result[date.weekday] ?? 0) + 1;
    }

    return result;
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.totalEarnings});

  final double totalEarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total gains', style: TextStyle(color: Color(0xFF757575))),
          const SizedBox(height: 8),
          Text(
            '${totalEarnings.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Color(0xFF1B8A5A),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.label,
    required this.count,
    required this.max,
  });

  final String label;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = count == 0 ? 0.04 : count / max;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: const Color(0xFFE6E8EC),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1B8A5A)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 72, child: Text('$count course${count > 1 ? 's' : ''}')),
        ],
      ),
    );
  }
}

class _DayInfo {
  const _DayInfo(this.index, this.label);

  final int index;
  final String label;
}

const _days = [
  _DayInfo(1, 'Lun'),
  _DayInfo(2, 'Mar'),
  _DayInfo(3, 'Mer'),
  _DayInfo(4, 'Jeu'),
  _DayInfo(5, 'Ven'),
  _DayInfo(6, 'Sam'),
  _DayInfo(7, 'Dim'),
];

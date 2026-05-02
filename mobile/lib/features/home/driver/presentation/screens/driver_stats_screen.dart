import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/driver_repository.dart';
import '../../data/models/driver_stats.dart';
import '../widgets/driver_stats_card.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            children: [
              _Header(onBack: () => Navigator.of(context).pop()),
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
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const _StatsErrorCard();
                  }
                  return _StatsContent(stats: snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = ref.read(driverRepositoryProvider).fetchStats();
    });
    await _statsFuture;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        const Text(
          'Mes stats',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RevenueSection(stats: stats),
        const SizedBox(height: 18),
        _RideStatusSection(stats: stats),
        const SizedBox(height: 18),
        _PeakHoursSection(stats: stats),
        const SizedBox(height: 18),
        _ProfitableZonesSection(stats: stats),
        const SizedBox(height: 18),
        _ReputationSection(stats: stats),
      ],
    );
  }
}

class _RevenueSection extends StatelessWidget {
  const _RevenueSection({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenus',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'aujourd hui',
                value: _formatFcfa(stats.revenue.today),
                icon: Icons.today_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'semaine',
                value: _formatFcfa(stats.revenue.week),
                icon: Icons.calendar_view_week_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'mois',
                value: _formatFcfa(stats.revenue.month),
                icon: Icons.calendar_month_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'total',
                value: _formatFcfa(stats.revenue.total),
                icon: Icons.savings_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RideStatusSection extends StatelessWidget {
  const _RideStatusSection({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Courses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'completees',
                value: '${stats.rides.completed}',
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'annulees',
                value: '${stats.rides.cancelled}',
                icon: Icons.cancel_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'refusees',
                value: '${stats.rides.refused}',
                icon: Icons.block_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeakHoursSection extends StatelessWidget {
  const _PeakHoursSection({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    final maxRides = stats.peakHours.fold<int>(
      1,
      (current, item) => item.completedRides > current ? item.completedRides : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Heures de pointe',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Nombre de courses completees par heure',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 360,
            child: RotatedBox(
              quarterTurns: 1,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxRides.toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 3 != 0 || hour < 0 || hour > 23) {
                            return const SizedBox.shrink();
                          }
                          return RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}h',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: stats.peakHours
                      .map(
                        (item) => BarChartGroupData(
                          x: item.hour,
                          barRods: [
                            BarChartRodData(
                              toY: item.completedRides.toDouble(),
                              width: 7,
                              borderRadius: BorderRadius.circular(4),
                              color: const Color(0xFF1B8A5A),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfitableZonesSection extends StatelessWidget {
  const _ProfitableZonesSection({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    final zones = stats.profitableZones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Zones rentables',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: zones.isEmpty
              ? const Text(
                  'Aucune zone rentable disponible pour le moment.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                )
              : Column(
                  children: [
                    for (var index = 0; index < zones.length; index++) ...[
                      _ZoneRow(rank: index + 1, zone: zones[index]),
                      if (index < zones.length - 1) const Divider(height: 18),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.rank,
    required this.zone,
  });

  final int rank;
  final DriverProfitableZoneStat zone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '#$rank',
          style: const TextStyle(
            color: Color(0xFF1B8A5A),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            zone.zoneName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${_formatFcfa(zone.averageRevenue)} / course',
          style: const TextStyle(
            color: Color(0xFF374151),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ReputationSection extends StatelessWidget {
  const _ReputationSection({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note 30 jours: ${stats.reputation.last30Days.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Note globale: ${stats.reputation.globalAverage.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsErrorCard extends StatelessWidget {
  const _StatsErrorCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Impossible de charger les stats pour le moment.',
        style: TextStyle(color: Color(0xFFE53935)),
      ),
    );
  }
}

String _formatFcfa(double value) {
  final rounded = value.round().toString();
  final withSpaces = rounded.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '$withSpaces FCFA';
}

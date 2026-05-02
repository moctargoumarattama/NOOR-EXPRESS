import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_surface_card.dart';
import '../../../shared/widgets/status_badge.dart';

class RideDetailScreen extends ConsumerStatefulWidget {
  const RideDetailScreen({
    super.key,
    required this.rideId,
    this.initialData,
  });

  final int rideId;
  final Map<String, dynamic>? initialData;

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  late Future<Map<String, dynamic>> _rideFuture;

  @override
  void initState() {
    super.initState();
    _rideFuture = _loadRide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _rideFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Ce trajet est indisponible.'));
            }

            final ride = snapshot.data!;
            final price = _priceOf(ride);
            final status = ride['status'] as String? ?? 'pending';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Detail de course',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ReceiptHeroCard(
                  rideId: widget.rideId,
                  status: status,
                  price: price,
                  dateLabel: _dateLabel(
                    (ride['completed_at'] ?? ride['created_at']) as String?,
                  ),
                  distanceLabel: _distanceLabel(ride),
                  durationLabel: _durationLabel(ride),
                ),
                const SizedBox(height: 14),
                _RouteCard(
                  pickup: ride['pickup_location'] as String? ?? 'Depart',
                  dropoff: ride['dropoff_location'] as String? ?? 'Destination',
                ),
                const SizedBox(height: 14),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resume financier',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Line('Prix final', '${price.toStringAsFixed(0)} FCFA'),
                      _Line('Statut', _statusLabel(status)),
                      if (_num(ride['platform_commission']) != null)
                        _Line(
                          'Commission admin',
                          '${_num(ride['platform_commission'])!.toStringAsFixed(0)} FCFA',
                        ),
                      if (_num(ride['driver_net_earnings']) != null)
                        _Line(
                          'Net chauffeur',
                          '${_num(ride['driver_net_earnings'])!.toStringAsFixed(0)} FCFA',
                        ),
                    ],
                  ),
                ),
                if (_num(ride['client_rating_for_driver']) != null ||
                    _num(ride['driver_rating_for_client']) != null) ...[
                  const SizedBox(height: 14),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes et avis',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_num(ride['client_rating_for_driver']) != null)
                          _Line(
                            'Note chauffeur',
                            '${_num(ride['client_rating_for_driver'])!.toStringAsFixed(1)}/5',
                          ),
                        if (_num(ride['driver_rating_for_client']) != null)
                          _Line(
                            'Note client',
                            '${_num(ride['driver_rating_for_client'])!.toStringAsFixed(1)}/5',
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadRide() async {
    if (widget.initialData != null) {
      return widget.initialData!;
    }
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<Map<String, dynamic>>('/ride-requests/${widget.rideId}');
      return response.data ?? <String, dynamic>{};
    } on DioException catch (_) {
      throw Exception('Ride indisponible');
    }
  }

  double _priceOf(Map<String, dynamic> ride) {
    return _num(ride['final_price']) ??
        _num(ride['agreed_price']) ??
        _num(ride['estimated_price']) ??
        0;
  }

  double? _num(Object? value) => value is num ? value.toDouble() : null;

  String _distanceLabel(Map<String, dynamic> ride) {
    final distanceKm = _num(ride['distance_km']);
    if (distanceKm == null || distanceKm <= 0) {
      return 'Distance non calculee';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String _durationLabel(Map<String, dynamic> ride) {
    final durationMinutes = ride['duration_minutes'] as num?;
    if (durationMinutes == null || durationMinutes.toInt() <= 0) {
      return 'Duree non calculee';
    }
    return '${durationMinutes.toInt()} min';
  }

  String _dateLabel(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) {
      return 'Date inconnue';
    }
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} a ${hour}h$minute';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'completed':
        return 'Trajet termine';
      case 'cancelled':
        return 'Trajet annule';
      case 'expired':
        return 'Demande terminee';
      case 'started':
        return 'Trajet en cours';
      default:
        return status ?? 'Trajet en cours';
    }
  }
}

class _ReceiptHeroCard extends StatelessWidget {
  const _ReceiptHeroCard({
    required this.rideId,
    required this.status,
    required this.price,
    required this.dateLabel,
    required this.distanceLabel,
    required this.durationLabel,
  });

  final int rideId;
  final String status;
  final double price;
  final String dateLabel;
  final String distanceLabel;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEEF8F2),
              Color(0xFFFFFFFF),
            ],
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0x141B8A5A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF1B8A5A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recu de course',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Paiement, trajet et statut confirmes',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '${price.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Course #$rideId - $dateLabel',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroPill(
                  icon: Icons.map_rounded,
                  label: distanceLabel,
                ),
                _HeroPill(
                  icon: Icons.schedule_rounded,
                  label: durationLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickup,
    required this.dropoff,
  });

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trajet effectue',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _RouteLine(
            icon: Icons.trip_origin_rounded,
            color: const Color(0xFF1B8A5A),
            label: 'Depart',
            value: pickup,
          ),
          const SizedBox(height: 14),
          _RouteLine(
            icon: Icons.flag_rounded,
            color: const Color(0xFFE53935),
            label: 'Destination',
            value: dropoff,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B8A5A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

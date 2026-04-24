import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

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
      backgroundColor: const Color(0xFFF8F9FA),
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
            final price = _num(ride['final_price']) ??
                _num(ride['agreed_price']) ??
                _num(ride['estimated_price']) ??
                0;
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
                    const Text(
                      'Detail du trajet',
                      style:
                          TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoCard(
                  title: 'Depart',
                  icon: Icons.trip_origin_rounded,
                  value: ride['pickup_location'] as String? ?? 'Depart',
                ),
                _InfoCard(
                  title: 'Destination',
                  icon: Icons.flag_rounded,
                  value: ride['dropoff_location'] as String? ?? 'Destination',
                ),
                _SectionCard(
                  title: 'Details',
                  children: [
                    _Line('Prix', '${price.toStringAsFixed(0)} FCFA'),
                    _Line('Distance', _distanceLabel(ride)),
                    const _Line('Duree', '~15 min'),
                    _Line('Date', _dateLabel(ride['created_at'] as String?)),
                  ],
                ),
                const _SectionCard(
                  title: 'Chauffeur',
                  children: [
                    _Line('Nom', 'Chauffeur Noor'),
                    _Line('Vehicule', 'Noor Express - Paiement en especes'),
                  ],
                ),
                _SectionCard(
                  title: 'Etat du trajet',
                  children: [
                    _Line('Trajet', _statusLabel(ride['status'] as String?)),
                  ],
                ),
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

  double? _num(Object? value) => value is num ? value.toDouble() : null;

  String _distanceLabel(Map<String, dynamic> ride) {
    final pickupLat = _num(ride['pickup_latitude']);
    final pickupLng = _num(ride['pickup_longitude']);
    final dropLat = _num(ride['dropoff_latitude']);
    final dropLng = _num(ride['dropoff_longitude']);
    if (pickupLat == null ||
        pickupLng == null ||
        dropLat == null ||
        dropLng == null) {
      return 'Non calculee';
    }
    return '~${((pickupLat - dropLat).abs() + (pickupLng - dropLng).abs()).toStringAsFixed(1)} km';
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
      default:
        return status ?? 'Trajet en cours';
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1B8A5A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Divider(height: 24),
          ...children,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

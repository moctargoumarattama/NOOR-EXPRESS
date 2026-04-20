import 'package:flutter/material.dart';

import '../../domain/entities/tracking_state.dart';
import 'eta_chip.dart';

class TrackingTopBar extends StatelessWidget {
  const TrackingTopBar({
    super.key,
    required this.connectionState,
    required this.onBack,
    this.etaMinutes,
  });

  final TrackingConnectionState connectionState;
  final int? etaMinutes;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.34),
          ),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const Spacer(),
        if (etaMinutes != null) EtaChip(label: 'ETA $etaMinutes min'),
        const SizedBox(width: 10),
        ConnectionBadge(connectionState: connectionState),
      ],
    );
  }
}

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({
    super.key,
    required this.connectionState,
  });

  final TrackingConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final label = switch (connectionState) {
      TrackingConnectionState.connected => 'Live',
      TrackingConnectionState.reconnecting => 'Reco',
      TrackingConnectionState.connecting => 'Connexion',
      TrackingConnectionState.disconnected => 'Offline',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TrackingEmptyCard extends StatelessWidget {
  const TrackingEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class TrackingErrorCard extends StatelessWidget {
  const TrackingErrorCard({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFEA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB84F3A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

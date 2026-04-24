import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_button.dart';
import '../../data/models/driver_ride.dart';
import 'driver_stats_card.dart';

class DriverBottomSheet extends StatelessWidget {
  const DriverBottomSheet({
    super.key,
    required this.isOnline,
    required this.isBusy,
    required this.todayRides,
    required this.todayEarnings,
    required this.activeRide,
    required this.onStart,
    required this.onStop,
    required this.onOpenTracking,
  });

  final bool isOnline;
  final bool isBusy;
  final int todayRides;
  final double todayEarnings;
  final DriverRide? activeRide;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.22,
      maxChildSize: 0.50,
      snap: true,
      snapSizes: const [0.28, 0.50],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (activeRide != null)
                _ActiveRidePanel(ride: activeRide!, onOpen: onOpenTracking)
              else if (isOnline)
                _OnlinePanel(
                  isBusy: isBusy,
                  todayRides: todayRides,
                  todayEarnings: todayEarnings,
                  onStop: onStop,
                )
              else
                _OfflinePanel(
                  isBusy: isBusy,
                  todayRides: todayRides,
                  todayEarnings: todayEarnings,
                  onStart: onStart,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({
    required this.isBusy,
    required this.todayRides,
    required this.todayEarnings,
    required this.onStart,
  });

  final bool isBusy;
  final int todayRides;
  final double todayEarnings;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
            icon: Icons.pause_circle,
            text: 'Vous etes en pause',
            color: Color(0xFFE53935)),
        const SizedBox(height: 8),
        Text(
          'Passez disponible pour recevoir les prochaines courses.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Recevoir des courses',
          icon: Icons.play_arrow_rounded,
          isLoading: isBusy,
          onPressed: isBusy ? null : onStart,
        ),
        const SizedBox(height: 16),
        _StatsRow(todayRides: todayRides, todayEarnings: todayEarnings),
      ],
    );
  }
}

class _OnlinePanel extends StatelessWidget {
  const _OnlinePanel({
    required this.isBusy,
    required this.todayRides,
    required this.todayEarnings,
    required this.onStop,
  });

  final bool isBusy;
  final int todayRides;
  final double todayEarnings;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
            icon: Icons.radio_button_checked,
            text: 'Vous etes disponible',
            color: Color(0xFF1B8A5A)),
        const SizedBox(height: 8),
        Text(
          'Nous vous prevenons des qu une course arrive.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _StatsRow(todayRides: todayRides, todayEarnings: todayEarnings),
        const SizedBox(height: 16),
        AppButton.danger(
          label: 'Faire une pause',
          icon: Icons.stop_rounded,
          isLoading: isBusy,
          onPressed: isBusy ? null : onStop,
        ),
      ],
    );
  }
}

class _ActiveRidePanel extends StatelessWidget {
  const _ActiveRidePanel({required this.ride, required this.onOpen});

  final DriverRide ride;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
            icon: Icons.local_taxi,
            text: 'Votre trajet en cours',
            color: Color(0xFFF5A623)),
        const SizedBox(height: 12),
        Text('${ride.pickupLocation} -> ${ride.dropoffLocation}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text(
          '${ride.displayPrice.toStringAsFixed(0)} FCFA cash',
          style: const TextStyle(
            color: Color(0xFF1B8A5A),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Ouvrir le trajet',
          icon: Icons.navigation_rounded,
          onPressed: onOpen,
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.todayRides, required this.todayEarnings});

  final int todayRides;
  final double todayEarnings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DriverStatsCard(
            label: 'Aujourd hui',
            value: '$todayRides trajets',
            icon: Icons.route_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DriverStatsCard(
            label: 'Vos gains',
            value: '${todayEarnings.toStringAsFixed(0)} FCFA',
            icon: Icons.payments_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatusTitle extends StatelessWidget {
  const _StatusTitle(
      {required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 10),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

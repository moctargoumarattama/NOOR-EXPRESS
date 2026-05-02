import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../data/models/driver_ride.dart';
import 'driver_stats_card.dart';

enum DriverRideSheetStage {
  idle,
  rideReceived,
  priceProposal,
  offerSent,
}

class DriverBottomSheet extends StatelessWidget {
  const DriverBottomSheet({
    super.key,
    required this.driverStatus,
    required this.isBusy,
    required this.todayRides,
    required this.todayEarnings,
    required this.activeRide,
    required this.onStart,
    required this.onStop,
    required this.onOpenTracking,
    this.pendingRide,
    this.flowStage = DriverRideSheetStage.idle,
    this.submittedOfferPrice,
    this.onProposePrice,
    this.onIgnoreRide,
    this.onSubmitOffer,
    this.onBackToRideReceived,
  });

  final String driverStatus;
  final bool isBusy;
  final int todayRides;
  final double todayEarnings;
  final DriverRide? activeRide;
  final DriverRide? pendingRide;
  final DriverRideSheetStage flowStage;
  final double? submittedOfferPrice;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onOpenTracking;
  final VoidCallback? onProposePrice;
  final VoidCallback? onIgnoreRide;
  final ValueChanged<double>? onSubmitOffer;
  final VoidCallback? onBackToRideReceived;

  @override
  Widget build(BuildContext context) {
    final isOnline = driverStatus == 'online';
    final isPaused = driverStatus == 'paused';
    final activeFlowStage =
        pendingRide == null ? DriverRideSheetStage.idle : flowStage;
    final sizing = _sheetSizing(activeFlowStage, activeRide != null);

    return DraggableScrollableSheet(
      initialChildSize: sizing.initial,
      minChildSize: sizing.min,
      maxChildSize: sizing.max,
      snap: true,
      snapSizes: [sizing.initial, sizing.max],
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
              const _SheetHandle(),
              const SizedBox(height: 18),
              if (activeRide != null)
                _ActiveRidePanel(ride: activeRide!, onOpen: onOpenTracking)
              else if (pendingRide != null &&
                  activeFlowStage != DriverRideSheetStage.idle)
                _DriverRideFlowPanel(
                  ride: pendingRide!,
                  stage: activeFlowStage,
                  submittedOfferPrice: submittedOfferPrice,
                  isSubmitting: isBusy,
                  onProposePrice: onProposePrice,
                  onIgnoreRide: onIgnoreRide,
                  onSubmitOffer: onSubmitOffer,
                  onBackToRideReceived: onBackToRideReceived,
                )
              else if (isOnline)
                _OnlinePanel(
                  isBusy: isBusy,
                  todayRides: todayRides,
                  todayEarnings: todayEarnings,
                  onStop: onStop,
                )
              else if (isPaused)
                _PausedPanel(
                  isBusy: isBusy,
                  todayRides: todayRides,
                  todayEarnings: todayEarnings,
                  onResume: onStart,
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

class _SheetSizing {
  const _SheetSizing({
    required this.initial,
    required this.min,
    required this.max,
  });

  final double initial;
  final double min;
  final double max;
}

_SheetSizing _sheetSizing(DriverRideSheetStage stage, bool hasActiveRide) {
  if (hasActiveRide) {
    return const _SheetSizing(initial: 0.28, min: 0.22, max: 0.50);
  }
  switch (stage) {
    case DriverRideSheetStage.rideReceived:
      return const _SheetSizing(initial: 0.56, min: 0.38, max: 0.72);
    case DriverRideSheetStage.priceProposal:
      return const _SheetSizing(initial: 0.58, min: 0.42, max: 0.75);
    case DriverRideSheetStage.offerSent:
      return const _SheetSizing(initial: 0.34, min: 0.28, max: 0.52);
    case DriverRideSheetStage.idle:
      return const _SheetSizing(initial: 0.28, min: 0.22, max: 0.50);
  }
}

class _DriverRideFlowPanel extends StatelessWidget {
  const _DriverRideFlowPanel({
    required this.ride,
    required this.stage,
    required this.isSubmitting,
    this.submittedOfferPrice,
    this.onProposePrice,
    this.onIgnoreRide,
    this.onSubmitOffer,
    this.onBackToRideReceived,
  });

  final DriverRide ride;
  final DriverRideSheetStage stage;
  final bool isSubmitting;
  final double? submittedOfferPrice;
  final VoidCallback? onProposePrice;
  final VoidCallback? onIgnoreRide;
  final ValueChanged<double>? onSubmitOffer;
  final VoidCallback? onBackToRideReceived;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      DriverRideSheetStage.rideReceived => _RideReceivedPanel(
          ride: ride,
          isSubmitting: isSubmitting,
          onProposePrice: onProposePrice,
          onIgnoreRide: onIgnoreRide,
        ),
      DriverRideSheetStage.priceProposal => _PriceProposalPanel(
          ride: ride,
          isSubmitting: isSubmitting,
          onSubmitOffer: onSubmitOffer,
          onBackToRideReceived: onBackToRideReceived,
        ),
      DriverRideSheetStage.offerSent => _OfferSentPanel(
          price: submittedOfferPrice,
        ),
      DriverRideSheetStage.idle => const SizedBox.shrink(),
    };
  }
}

class _RideReceivedPanel extends StatelessWidget {
  const _RideReceivedPanel({
    required this.ride,
    required this.isSubmitting,
    this.onProposePrice,
    this.onIgnoreRide,
  });

  final DriverRide ride;
  final bool isSubmitting;
  final VoidCallback? onProposePrice;
  final VoidCallback? onIgnoreRide;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = _distanceToPickupLabel(ride.distanceToPickupKm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
          icon: Icons.local_taxi_rounded,
          text: 'Une course vous attend',
          color: AppColors.emerald,
        ),
        const SizedBox(height: 14),
        _AddressLine(
          label: 'Point de prise en charge',
          value: ride.pickupLocation,
          subtitle: distanceLabel,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 11, top: 3, bottom: 3),
          child: Icon(Icons.arrow_downward_rounded, size: 18),
        ),
        _AddressLine(
          label: 'Destination',
          value: ride.dropoffLocation,
        ),
        const SizedBox(height: 14),
        _InfoRow(label: 'Prix client', value: _priceLabel(ride.estimatedPrice)),
        const SizedBox(height: 14),
        AppButton(
          label: 'Proposer un prix',
          icon: Icons.payments_rounded,
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onProposePrice,
        ),
        const SizedBox(height: 10),
        AppButton.secondary(
          label: 'Ignorer',
          icon: Icons.close_rounded,
          onPressed: isSubmitting ? null : onIgnoreRide,
        ),
      ],
    );
  }
}

class _PriceProposalPanel extends StatefulWidget {
  const _PriceProposalPanel({
    required this.ride,
    required this.isSubmitting,
    this.onSubmitOffer,
    this.onBackToRideReceived,
  });

  final DriverRide ride;
  final bool isSubmitting;
  final ValueChanged<double>? onSubmitOffer;
  final VoidCallback? onBackToRideReceived;

  @override
  State<_PriceProposalPanel> createState() => _PriceProposalPanelState();
}

class _PriceProposalPanelState extends State<_PriceProposalPanel> {
  static const _stepFcfa = 100.0;

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialPriceText());
    _controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _PriceProposalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.id != widget.ride.id ||
        oldWidget.ride.estimatedPrice != widget.ride.estimatedPrice) {
      _controller.text = _initialPriceText();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice = _currentPrice;
    final canSubmit = !widget.isSubmitting &&
        widget.onSubmitOffer != null &&
        _isValidDriverPrice(currentPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
          icon: Icons.tune_rounded,
          text: 'Votre proposition',
          color: AppColors.emerald,
        ),
        const SizedBox(height: 12),
        _InfoRow(
            label: 'Prix client',
            value: _priceLabel(widget.ride.estimatedPrice)),
        const SizedBox(height: 12),
        _PriceStepper(
          controller: _controller,
          onDecrease: _decreasePrice,
          onIncrease: _increasePrice,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Envoyer ma proposition',
          icon: Icons.send_rounded,
          isLoading: widget.isSubmitting,
          onPressed:
              canSubmit ? () => widget.onSubmitOffer!(currentPrice!) : null,
        ),
        const SizedBox(height: 10),
        AppButton.secondary(
          label: 'Pas maintenant',
          icon: Icons.arrow_back_rounded,
          onPressed: widget.isSubmitting ? null : widget.onBackToRideReceived,
        ),
      ],
    );
  }

  String _initialPriceText() {
    final price = widget.ride.estimatedPrice;
    if (!_isValidDriverPrice(price)) {
      return '';
    }
    return price.round().toString();
  }

  double? get _currentPrice {
    final raw = _controller.text.trim().replaceAll(',', '.');
    return double.tryParse(raw);
  }

  void _decreasePrice() {
    final price = _currentPrice;
    if (!_isValidDriverPrice(price)) {
      return;
    }
    final next = price! - _stepFcfa;
    _setPrice(next);
  }

  void _increasePrice() {
    final price = _currentPrice;
    final next = _isValidDriverPrice(price)
        ? price! + _stepFcfa
        : widget.ride.estimatedPrice;
    _setPrice(next);
  }

  void _setPrice(double value) {
    _controller.text = value.round().toString();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _OfferSentPanel extends StatelessWidget {
  const _OfferSentPanel({required this.price});

  final double? price;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
          icon: Icons.check_circle_rounded,
          text: 'Offre envoyee',
          color: AppColors.emerald,
        ),
        const SizedBox(height: 10),
        Text(
          'En attente de la reponse du client',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        _InfoRow(label: 'Votre proposition', value: _priceLabel(price)),
      ],
    );
  }
}

class _PriceStepper extends StatelessWidget {
  const _PriceStepper({
    required this.controller,
    required this.onDecrease,
    required this.onIncrease,
  });

  final TextEditingController controller;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundActionButton(
          icon: Icons.remove_rounded,
          onTap: onDecrease,
          tooltip: 'Diminuer le prix',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Votre prix',
              suffixText: 'FCFA',
              filled: true,
              fillColor: AppColors.cloud,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _RoundActionButton(
          icon: Icons.add_rounded,
          onTap: onIncrease,
          tooltip: 'Augmenter le prix',
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.mint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: AppColors.emerald),
          ),
        ),
      ),
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
          icon: Icons.power_settings_new_rounded,
          text: 'Vous etes hors ligne',
          color: Color(0xFF8A8D93),
        ),
        const SizedBox(height: 8),
        Text(
          'Passez en ligne pour recevoir les prochaines courses.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Passer en ligne',
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

class _PausedPanel extends StatelessWidget {
  const _PausedPanel({
    required this.isBusy,
    required this.todayRides,
    required this.todayEarnings,
    required this.onResume,
  });

  final bool isBusy;
  final int todayRides;
  final double todayEarnings;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTitle(
          icon: Icons.pause_circle_rounded,
          text: 'Vous etes en pause',
          color: Color(0xFFF29A2E),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous ne recevez plus de nouvelles courses pour le moment.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Repasser en ligne',
          icon: Icons.play_arrow_rounded,
          isLoading: isBusy,
          onPressed: isBusy ? null : onResume,
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
          color: AppColors.emerald,
        ),
        const SizedBox(height: 8),
        Text(
          'En attente de courses',
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
          color: AppColors.gold,
        ),
        const SizedBox(height: 12),
        Text(
          '${ride.pickupLocation} -> ${ride.dropoffLocation}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          _priceLabel(ride.displayPrice),
          style: const TextStyle(
            color: AppColors.emerald,
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

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.place_rounded, color: AppColors.emerald),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.stone,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.emerald,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.stone,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.emerald,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
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
            value: _priceLabel(todayEarnings),
            icon: Icons.payments_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatusTitle extends StatelessWidget {
  const _StatusTitle({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

bool _isValidDriverPrice(double? price) {
  return price != null && price.isFinite && price > 0 && price <= 500000;
}

String _priceLabel(double? price) {
  if (!_isValidDriverPrice(price)) {
    return 'Prix indisponible';
  }
  return '${price!.round()} FCFA';
}

String? _distanceToPickupLabel(double? distanceKm) {
  if (distanceKm == null || !distanceKm.isFinite || distanceKm <= 0) {
    return null;
  }
  return 'A ${distanceKm.toStringAsFixed(1)} km de vous';
}

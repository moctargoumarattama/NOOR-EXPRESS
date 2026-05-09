import 'dart:async';

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
    this.onQuickOffer,
    this.onQuickOfferSuccess,
    this.onRideRequestTimedOut,
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
  final Future<bool> Function(double price)? onQuickOffer;
  final ValueChanged<double>? onQuickOfferSuccess;
  final VoidCallback? onRideRequestTimedOut;
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
                  onQuickOffer: onQuickOffer,
                  onQuickOfferSuccess: onQuickOfferSuccess,
                  onRideRequestTimedOut: onRideRequestTimedOut,
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
    this.onQuickOffer,
    this.onQuickOfferSuccess,
    this.onRideRequestTimedOut,
    this.onSubmitOffer,
    this.onBackToRideReceived,
  });

  final DriverRide ride;
  final DriverRideSheetStage stage;
  final bool isSubmitting;
  final double? submittedOfferPrice;
  final VoidCallback? onProposePrice;
  final VoidCallback? onIgnoreRide;
  final Future<bool> Function(double price)? onQuickOffer;
  final ValueChanged<double>? onQuickOfferSuccess;
  final VoidCallback? onRideRequestTimedOut;
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
          onQuickOffer: onQuickOffer,
          onQuickOfferSuccess: onQuickOfferSuccess,
          onRideRequestTimedOut: onRideRequestTimedOut,
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

class _RideReceivedPanel extends StatefulWidget {
  const _RideReceivedPanel({
    required this.ride,
    required this.isSubmitting,
    this.onProposePrice,
    this.onIgnoreRide,
    this.onQuickOffer,
    this.onQuickOfferSuccess,
    this.onRideRequestTimedOut,
  });

  final DriverRide ride;
  final bool isSubmitting;
  final VoidCallback? onProposePrice;
  final VoidCallback? onIgnoreRide;
  final Future<bool> Function(double price)? onQuickOffer;
  final ValueChanged<double>? onQuickOfferSuccess;
  final VoidCallback? onRideRequestTimedOut;

  @override
  State<_RideReceivedPanel> createState() => _RideReceivedPanelState();
}

class _RideReceivedPanelState extends State<_RideReceivedPanel> {
  static const _countdownTotalSeconds = 45;
  static const _minimumLoaderDuration = Duration(seconds: 1);

  Timer? _countdownTimer;
  int _remainingSeconds = _countdownTotalSeconds;
  bool _isClosing = false;
  bool _isQuickSending = false;
  bool _showSentFeedback = false;
  double? _selectedQuickPrice;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant _RideReceivedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.id != widget.ride.id) {
      _resetCountdownForNewRide();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel =
        _distanceToPickupLabel(widget.ride.distanceToPickupKm);
    final quickOptions = _quickOptions(widget.ride.estimatedPrice);
    final isBusy = widget.isSubmitting || _isQuickSending;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      offset: _isClosing ? const Offset(0, 0.12) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _isClosing ? 0 : 1,
        child: Column(
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
              value: widget.ride.pickupLocation,
              subtitle: distanceLabel,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 11, top: 3, bottom: 3),
              child: Icon(Icons.arrow_downward_rounded, size: 18),
            ),
            _AddressLine(
              label: 'Destination',
              value: widget.ride.dropoffLocation,
            ),
            const SizedBox(height: 12),
            _PassengerPriceTimer(
              price: widget.ride.estimatedPrice,
              remainingSeconds: _remainingSeconds,
              totalSeconds: _countdownTotalSeconds,
            ),
            const SizedBox(height: 14),
            if (_showSentFeedback)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x1E1B8A5A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Offre envoyee \u2713',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  for (var index = 0; index < quickOptions.length; index++) ...[
                    Expanded(
                      child: _QuickPriceButton(
                        amount: quickOptions[index].amount,
                        label: quickOptions[index].label,
                        isPrimary: quickOptions[index].isPrimary,
                        isBusy: isBusy,
                        isSelected:
                            _selectedQuickPrice == quickOptions[index].amount,
                        onTap: () =>
                            _handleQuickOfferTap(quickOptions[index].amount),
                      ),
                    ),
                    if (index != quickOptions.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isBusy ? null : widget.onProposePrice,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.stone,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Autre prix \u2192'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            AppButton.secondary(
              label: 'Ignorer',
              icon: Icons.close_rounded,
              onPressed: isBusy ? null : widget.onIgnoreRide,
            ),
          ],
        ),
      ),
    );
  }

  List<_QuickPriceOption> _quickOptions(double passengerPrice) {
    final basePrice = passengerPrice > 0 ? passengerPrice : 0.0;
    return [
      _QuickPriceOption(
        amount: basePrice,
        label: 'Accepter tel quel',
        isPrimary: true,
      ),
      _QuickPriceOption(
        amount: basePrice + 200,
        label: '+200',
      ),
      _QuickPriceOption(
        amount: basePrice + 500,
        label: '+500',
      ),
    ];
  }

  void _resetCountdownForNewRide() {
    _countdownTimer?.cancel();
    _remainingSeconds = _countdownTotalSeconds;
    _isClosing = false;
    _isQuickSending = false;
    _showSentFeedback = false;
    _selectedQuickPrice = null;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isClosing || _isQuickSending || _showSentFeedback) {
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _animateAndCloseByTimeout();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _animateAndCloseByTimeout() async {
    if (_isClosing || !mounted) {
      return;
    }
    setState(() {
      _isClosing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) {
      return;
    }
    widget.onRideRequestTimedOut?.call();
  }

  Future<void> _handleQuickOfferTap(double proposedPrice) async {
    final onQuickOffer = widget.onQuickOffer;
    if (onQuickOffer == null ||
        _isQuickSending ||
        widget.isSubmitting ||
        _showSentFeedback) {
      return;
    }

    _countdownTimer?.cancel();
    setState(() {
      _isQuickSending = true;
      _selectedQuickPrice = proposedPrice;
    });

    final watch = Stopwatch()..start();
    final success = await onQuickOffer(proposedPrice);
    watch.stop();

    final remainingDelay = _minimumLoaderDuration - watch.elapsed;
    if (remainingDelay > Duration.zero) {
      await Future<void>.delayed(remainingDelay);
    }
    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _isQuickSending = false;
        _selectedQuickPrice = null;
      });
      _startCountdown();
      return;
    }

    setState(() {
      _isQuickSending = false;
      _showSentFeedback = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) {
      return;
    }

    setState(() {
      _isClosing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    widget.onQuickOfferSuccess?.call(proposedPrice);
  }
}

class _QuickPriceOption {
  const _QuickPriceOption({
    required this.amount,
    required this.label,
    this.isPrimary = false,
  });

  final double amount;
  final String label;
  final bool isPrimary;
}

class _QuickPriceButton extends StatelessWidget {
  const _QuickPriceButton({
    required this.amount,
    required this.label,
    required this.isPrimary,
    required this.isBusy,
    required this.isSelected,
    required this.onTap,
  });

  final double amount;
  final String label;
  final bool isPrimary;
  final bool isBusy;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? AppColors.pearl : AppColors.ink;
    final background = isPrimary ? AppColors.emerald : const Color(0xFFF0F3F2);

    return SizedBox(
      height: 68,
      child: FilledButton(
        onPressed: isBusy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.52),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isBusy && isSelected
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Envoi...',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _priceLabel(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PassengerPriceTimer extends StatelessWidget {
  const _PassengerPriceTimer({
    required this.price,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  final double price;
  final int remainingSeconds;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    final ringColor = progress <= 0.2
        ? AppColors.error
        : progress <= 0.45
            ? AppColors.warning
            : AppColors.emerald;

    return Row(
      children: [
        const Expanded(
          child: _InfoRow(
            label: 'Reponse rapide',
            value: 'Choisissez un prix en 2 taps',
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 106,
                    height: 106,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor: const Color(0xFFF1F3F2),
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Prix client',
                        style: TextStyle(
                          color: AppColors.stone,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _priceLabel(price),
                        style: const TextStyle(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$remainingSeconds s',
              style: TextStyle(
                color: ringColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
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

part of 'search_bottom_sheet.dart';

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.route,
    required this.routeError,
    required this.recentDepartureLabels,
    required this.priceController,
    required this.isCreating,
    required this.isEstimatingPrice,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    this.estimate,
    this.estimateError,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final RouteResult? route;
  final String? routeError;
  final List<String> recentDepartureLabels;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final PriceEstimate? estimate;
  final String? estimateError;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (dropoff == null) {
      return _IdlePanel(
        pickup: pickup,
        recentLabels: _recentLabels,
        onPickupTap: onPickupTap,
        onDropoffTap: onDropoffTap,
        onClearPickup: onClearPickup,
      );
    }

    return _RoutePreviewPanel(
      pickup: pickup,
      dropoff: dropoff,
      route: route,
      routeError: routeError,
      priceController: priceController,
      isCreating: isCreating,
      isEstimatingPrice: isEstimatingPrice,
      estimate: estimate,
      estimateError: estimateError,
      onPickupTap: onPickupTap,
      onDropoffTap: onDropoffTap,
      onClearPickup: onClearPickup,
      onClearDropoff: onClearDropoff,
      onSubmit: onSubmit,
    );
  }

  List<String> get _recentLabels {
    if (recentDepartureLabels.isNotEmpty) {
      return recentDepartureLabels.take(3).toList();
    }
    return const [
      'Grand Marche',
      'Aeroport Diori Hamani',
      'Universite Abdou Moumouni',
    ];
  }
}

class _IdlePanel extends StatelessWidget {
  const _IdlePanel({
    required this.pickup,
    required this.recentLabels,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
  });

  final AddressResult? pickup;
  final List<String> recentLabels;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RideModeHeader(
          title: 'Votre destination',
          subtitle: 'Choisissez une destination pour estimer la course.',
        ),
        const SizedBox(height: 16),
        _SearchLauncher(onTap: onDropoffTap),
        const SizedBox(height: 14),
        _PickupMiniCard(
          pickup: pickup,
          onTap: onPickupTap,
          onClear: pickup == null ? null : onClearPickup,
        ),
        const SizedBox(height: 18),
        Text(
          'Adresses recentes',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        for (final label in recentLabels) _RecentAddress(label: label),
      ],
    );
  }
}

class _RoutePreviewPanel extends StatelessWidget {
  const _RoutePreviewPanel({
    required this.pickup,
    required this.dropoff,
    required this.route,
    required this.routeError,
    required this.priceController,
    required this.isCreating,
    required this.isEstimatingPrice,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    this.estimate,
    this.estimateError,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final RouteResult? route;
  final String? routeError;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final PriceEstimate? estimate;
  final String? estimateError;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final reliableRecommendedPrice = _reliableRecommendedPrice;
    final canSubmit = pickup != null && dropoff != null && !isCreating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RideModeHeader(
          title: 'Votre course',
          subtitle: 'Verifiez le trajet puis proposez votre prix.',
        ),
        const SizedBox(height: 16),
        AddressInputCard(
          pickup: pickup,
          dropoff: dropoff,
          onPickupTap: onPickupTap,
          onDropoffTap: onDropoffTap,
          onClearPickup: onClearPickup,
          onClearDropoff: onClearDropoff,
        ),
        const SizedBox(height: 14),
        if (isEstimatingPrice) ...[
          const AppInlineFeedback(
            message: 'On calcule la distance, la duree et le prix conseille...',
            tone: AppInlineFeedbackTone.info,
            isLoading: true,
          ),
          const SizedBox(height: 14),
        ],
        RouteSummaryCard(
          pickupLabel: pickup?.name ?? 'Choisir le depart',
          dropoffLabel: dropoff?.name ?? 'Choisir l arrivee',
          distanceKm: route?.distanceKm,
          durationMinutes: route?.durationMinutes,
          recommendedPrice: reliableRecommendedPrice,
          reliabilityMessage: _reliabilityMessage,
        ),
        const SizedBox(height: 14),
        PriceSelector(
          controller: priceController,
          recommendedPrice: reliableRecommendedPrice,
          enabled: !isCreating,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Trouver un chauffeur',
          icon: Icons.local_taxi_rounded,
          isLoading: isCreating,
          onPressed: canSubmit ? onSubmit : null,
        ),
      ],
    );
  }

  double? get _reliableRecommendedPrice {
    final value = estimate?.estimatedPrice;
    final estimateDistance = estimate?.distanceKm;
    if (value == null ||
        estimateDistance == null ||
        !value.isFinite ||
        !estimateDistance.isFinite ||
        value <= 0 ||
        value > 500000 ||
        estimateDistance <= 0) {
      return null;
    }
    return value;
  }

  String? get _reliabilityMessage {
    final hasReliableRoute = route != null &&
        route!.distanceKm.isFinite &&
        route!.distanceKm > 0 &&
        route!.durationMinutes > 0;
    final hasReliablePrice = _reliableRecommendedPrice != null;
    final cleanedEstimateError = estimateError?.trim();
    final cleanedRouteError = routeError?.trim();

    if (!hasReliableRoute && !hasReliablePrice) {
      return 'Distance, duree et prix ne sont pas encore fiables. '
          'Verifiez les adresses ou reessayez.';
    }
    if (!hasReliableRoute) {
      return cleanedRouteError == null || cleanedRouteError.isEmpty
          ? 'Distance et duree ne sont pas encore fiables.'
          : cleanedRouteError;
    }
    if (!hasReliablePrice) {
      return cleanedEstimateError == null || cleanedEstimateError.isEmpty
          ? 'Prix recommande indisponible pour ce trajet. '
              'Vous pouvez saisir votre prix.'
          : cleanedEstimateError;
    }
    if (cleanedRouteError != null && cleanedRouteError.isNotEmpty) {
      return cleanedRouteError;
    }
    return null;
  }
}

class _SearchingRidePanel extends StatefulWidget {
  const _SearchingRidePanel({
    super.key,
    required this.ride,
    required this.onOpen,
    required this.route,
    this.nearbyDriversCount,
    this.onCancel,
  });

  final ClientRide ride;
  final RouteResult? route;
  final int? nearbyDriversCount;
  final VoidCallback onOpen;
  final VoidCallback? onCancel;

  @override
  State<_SearchingRidePanel> createState() => _SearchingRidePanelState();
}

class _SearchingRidePanelState extends State<_SearchingRidePanel> {
  late final TextEditingController _proposedPriceController;

  @override
  void initState() {
    super.initState();
    _proposedPriceController = TextEditingController(text: _priceText);
  }

  @override
  void didUpdateWidget(covariant _SearchingRidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.displayPrice == widget.ride.displayPrice) {
      return;
    }
    _proposedPriceController.text = _priceText;
  }

  @override
  void dispose() {
    _proposedPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchingHeader(),
        const SizedBox(height: 14),
        RouteSummaryCard(
          pickupLabel: widget.ride.pickupLocation,
          dropoffLabel: widget.ride.dropoffLocation,
          distanceKm: widget.route?.distanceKm,
          durationMinutes: widget.route?.durationMinutes,
          reliabilityMessage: _routeReliabilityMessage,
        ),
        const SizedBox(height: 12),
        PriceSelector(
          controller: _proposedPriceController,
          enabled: false,
          compact: true,
          helperText: _hasReliableProposedPrice
              ? 'Prix envoye aux chauffeurs'
              : 'Prix propose indisponible pour cette demande.',
        ),
        const SizedBox(height: 14),
        AppInlineFeedback(
          message: _feedbackMessage,
          tone: AppInlineFeedbackTone.info,
          isLoading: widget.ride.status == 'pending',
        ),
        const SizedBox(height: 16),
        if (_hasOffers) ...[
          AppButton(
            label: 'Voir les offres',
            icon: Icons.receipt_long_rounded,
            onPressed: widget.onOpen,
          ),
          const SizedBox(height: 10),
        ],
        AppButton.secondary(
          label: 'Annuler la demande',
          icon: Icons.close_rounded,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }

  bool get _hasOffers => widget.ride.status == 'offered';

  bool get _hasReliableProposedPrice {
    final value = widget.ride.displayPrice;
    return value.isFinite && value > 0 && value <= 500000;
  }

  String get _priceText {
    if (!_hasReliableProposedPrice) {
      return '';
    }
    return widget.ride.displayPrice.round().toString();
  }

  String? get _routeReliabilityMessage {
    final route = widget.route;
    final hasReliableRoute = route != null &&
        route.distanceKm.isFinite &&
        route.distanceKm > 0 &&
        route.durationMinutes > 0;
    if (hasReliableRoute) {
      return null;
    }
    return 'Distance et duree validees indisponibles pour cette demande.';
  }

  String get _feedbackMessage {
    if (_hasOffers) {
      return 'Des offres sont disponibles. Vous pouvez les comparer.';
    }
    final count = widget.nearbyDriversCount;
    if (count != null && count > 0) {
      final label = count == 1 ? 'chauffeur proche' : 'chauffeurs proches';
      return '$count $label consultent votre demande.';
    }
    return 'Recherche de chauffeurs...';
  }
}

class _SearchingHeader extends StatelessWidget {
  const _SearchingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'On cherche un chauffeur',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'En cours',
            style: TextStyle(
              color: AppColors.emerald,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF1B8A5A)),
            SizedBox(width: 12),
            Text(
              'Ou allez-vous ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAddress extends StatelessWidget {
  const _RecentAddress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF757575)),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _RideModeHeader extends StatelessWidget {
  const _RideModeHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Course',
                  style: TextStyle(
                    color: Color(0xFF1B8A5A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF757575),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupMiniCard extends StatelessWidget {
  const _PickupMiniCard({
    required this.pickup,
    required this.onTap,
    this.onClear,
  });

  final AddressResult? pickup;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A5A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.trip_origin_rounded,
                color: Color(0xFF1B8A5A),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Point de prise en charge',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF757575),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pickup?.name ?? 'Ma position actuelle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear ?? onTap,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                onClear == null
                    ? Icons.chevron_right_rounded
                    : Icons.close_rounded,
                color: const Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

part of 'search_bottom_sheet.dart';

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.route,
    required this.routeError,
    required this.recentDepartureLabels,
    required this.recentAddresses,
    required this.priceController,
    required this.isCreating,
    required this.isEstimatingPrice,
    required this.pickupLocationQuality,
    required this.canSubmitRideRequest,
    required this.submitDisabledReason,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onRecentTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    this.onAddToFavorites,
    this.estimate,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final RouteResult? route;
  final String? routeError;
  final List<String> recentDepartureLabels;
  final List<AddressResult> recentAddresses;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final LocationQuality pickupLocationQuality;
  final bool canSubmitRideRequest;
  final String? submitDisabledReason;
  final PriceEstimate? estimate;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final SelectRecentAddress? onRecentTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;
  final AddDropoffToFavorites? onAddToFavorites;

  @override
  Widget build(BuildContext context) {
    if (dropoff == null) {
      return _IdlePanel(
        pickup: pickup,
        pickupLocationQuality: pickupLocationQuality,
        recentLabels: _recentLabels,
        recentAddresses: recentAddresses,
        onPickupTap: onPickupTap,
        onDropoffTap: onDropoffTap,
        onRecentTap: onRecentTap,
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
      canSubmitRideRequest: canSubmitRideRequest,
      submitDisabledReason: submitDisabledReason,
      estimate: estimate,
      onPickupTap: onPickupTap,
      onDropoffTap: onDropoffTap,
      onClearPickup: onClearPickup,
      onClearDropoff: onClearDropoff,
      onSubmit: onSubmit,
      onAddToFavorites: onAddToFavorites,
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
    required this.pickupLocationQuality,
    required this.recentLabels,
    required this.recentAddresses,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onRecentTap,
    required this.onClearPickup,
  });

  final AddressResult? pickup;
  final LocationQuality pickupLocationQuality;
  final List<String> recentLabels;
  final List<AddressResult> recentAddresses;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final SelectRecentAddress? onRecentTap;
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
          pickupLocationQuality: pickupLocationQuality,
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
        if (recentAddresses.isNotEmpty)
          for (final address in recentAddresses.take(3))
            _RecentAddressAction(
              label: address.name,
              onTap: onRecentTap == null ? null : () => onRecentTap!(address),
            )
        else
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
    required this.canSubmitRideRequest,
    required this.submitDisabledReason,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    this.onAddToFavorites,
    this.estimate,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final RouteResult? route;
  final String? routeError;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final bool canSubmitRideRequest;
  final String? submitDisabledReason;
  final PriceEstimate? estimate;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;
  final AddDropoffToFavorites? onAddToFavorites;

  @override
  Widget build(BuildContext context) {
    final reliableRecommendedPrice = _reliableRecommendedPrice;
    final hasPickup = pickup != null;
    final canSubmit =
        hasPickup && dropoff != null && !isCreating && canSubmitRideRequest;
    final helperText = isEstimatingPrice
        ? 'Estimation en cours...'
        : 'Ajustez votre proposition avant d\'envoyer.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirmez votre trajet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Proposez un prix clair pour recevoir des offres rapidement.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        RouteSummaryCard(
          pickupLabel: pickup?.name ?? 'Choisir le depart',
          dropoffLabel: dropoff?.name ?? 'Choisir l arrivee',
          distanceKm: route?.distanceKm,
          durationMinutes: route?.durationMinutes,
          isRouteReliable: route?.hasReliableMetrics ?? false,
          recommendedPrice: reliableRecommendedPrice,
          minimumPrice: _reliableMinimumPrice,
          maximumPrice: _reliableMaximumPrice,
          availableDriversCount: _availabilityCount,
          reliabilityMessage: isEstimatingPrice
              ? 'Estimation en cours...'
              : _reliabilityMessage,
          compact: true,
        ),
        const SizedBox(height: 12),
        PriceSelector(
          controller: priceController,
          recommendedPrice: reliableRecommendedPrice,
          enabled: !isCreating,
          helperText: helperText,
        ),
        const SizedBox(height: 10),
        if (onAddToFavorites != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isCreating ? null : () => onAddToFavorites!(dropoff!),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.nigerOrangeDark,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              icon: const Icon(Icons.bookmark_add_rounded, size: 18),
              label: const Text('Ajouter aux favoris'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (submitDisabledReason != null) ...[
          const SizedBox(height: 8),
          AppInlineFeedback(
            message: submitDisabledReason!,
            tone: AppInlineFeedbackTone.warning,
          ),
        ] else if (!hasPickup) ...[
          const SizedBox(height: 8),
          const AppInlineFeedback(
            message:
                'Selectionnez votre point de depart avant de continuer.',
            tone: AppInlineFeedbackTone.warning,
          ),
        ],
        const SizedBox(height: 4),
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

  double? get _reliableMinimumPrice {
    final minimumPrice = estimate?.minPrice;
    final maximumPrice = estimate?.maxPrice;
    if (minimumPrice == null ||
        maximumPrice == null ||
        !_isReliableEstimatedPrice(minimumPrice) ||
        !_isReliableEstimatedPrice(maximumPrice) ||
        maximumPrice < minimumPrice) {
      return null;
    }
    return minimumPrice;
  }

  double? get _reliableMaximumPrice {
    final minimumPrice = _reliableMinimumPrice;
    final maximumPrice = estimate?.maxPrice;
    if (minimumPrice == null ||
        maximumPrice == null ||
        !_isReliableEstimatedPrice(maximumPrice) ||
        maximumPrice < minimumPrice) {
      return null;
    }
    return maximumPrice;
  }

  int? get _availabilityCount {
    final count = estimate?.availableDriversCount;
    if (count == null || count < 0) {
      return null;
    }
    return count;
  }

  String? get _reliabilityMessage {
    final hasReliableRoute = route?.hasReliableMetrics ?? false;
    final hasReliablePrice = _reliableRecommendedPrice != null;
    final cleanedRouteError = routeError?.trim();

    if (route?.isFallback == true && !hasReliablePrice) {
      return 'Estimation indisponible';
    }
    if (route?.isFallback == true) {
      return 'Estimation indisponible';
    }

    if (!hasReliableRoute && !hasReliablePrice) {
      return 'Estimation indisponible';
    }
    if (!hasReliableRoute) {
      return 'Estimation indisponible';
    }
    if (!hasReliablePrice) {
      return 'Estimation indisponible';
    }
    if (cleanedRouteError != null && cleanedRouteError.isNotEmpty) {
      return cleanedRouteError;
    }
    return null;
  }

  bool _isReliableEstimatedPrice(double value) {
    return value.isFinite && value > 0 && value <= 500000;
  }
}

class _OfferReceivedPanel extends StatefulWidget {
  const _OfferReceivedPanel({
    super.key,
    required this.ride,
    required this.route,
    required this.offers,
    this.isRefreshingOffers = false,
    this.acceptingOfferId,
    this.rejectingOfferId,
    this.onAcceptOffer,
    this.onRejectOffer,
    this.onViewAllOffers,
  });

  final ClientRide ride;
  final RouteResult? route;
  final List<RideOfferModel> offers;
  final bool isRefreshingOffers;
  final int? acceptingOfferId;
  final int? rejectingOfferId;
  final ValueChanged<RideOfferModel>? onAcceptOffer;
  final ValueChanged<RideOfferModel>? onRejectOffer;
  final VoidCallback? onViewAllOffers;

  @override
  State<_OfferReceivedPanel> createState() => _OfferReceivedPanelState();
}

class _OfferReceivedPanelState extends State<_OfferReceivedPanel> {
  static const _previewLimit = 3;
  bool _showAllOffers = false;

  @override
  Widget build(BuildContext context) {
    final hasBusyOffer =
        widget.acceptingOfferId != null || widget.rejectingOfferId != null;
    final hasMoreThanPreview = widget.offers.length > _previewLimit;
    final visibleOffers = _showAllOffers
        ? widget.offers
        : widget.offers.take(_previewLimit).toList(growable: false);
    final title = widget.offers.length == 1
        ? '1 offre recue'
        : '${widget.offers.length} offres recues';
    final toggleLabel = _showAllOffers
        ? 'Replier la liste'
        : hasMoreThanPreview
            ? 'Voir ${widget.offers.length - _previewLimit} autres offres'
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OfferReceivedHeader(
          title: title,
          subtitle: 'Comparez et choisissez le meilleur chauffeur.',
          badgeLabel: 'Nouveau',
        ),
        const SizedBox(height: 12),
        _CompactRideSummary(ride: widget.ride, route: widget.route),
        if (widget.isRefreshingOffers) ...[
          const SizedBox(height: 10),
          const AppInlineFeedback(
            message: 'Mise a jour des offres...',
            tone: AppInlineFeedbackTone.info,
            isLoading: true,
          ),
        ],
        if (toggleLabel != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAllOffers = !_showAllOffers),
              icon: Icon(
                _showAllOffers
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.list_alt_rounded,
                size: 18,
              ),
              label: Text(toggleLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.nigerOrangeDark,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (var index = 0; index < visibleOffers.length; index++) ...[
          OfferCard(
            offer: visibleOffers[index],
            compact: true,
            isAccepting:
                widget.acceptingOfferId == visibleOffers[index].offerId,
            isRejecting:
                widget.rejectingOfferId == visibleOffers[index].offerId,
            isDisabled: hasBusyOffer &&
                widget.acceptingOfferId != visibleOffers[index].offerId &&
                widget.rejectingOfferId != visibleOffers[index].offerId,
            onSelect: widget.onAcceptOffer == null
                ? () {}
                : () => widget.onAcceptOffer!(visibleOffers[index]),
            onReject: widget.onRejectOffer == null
                ? null
                : () => widget.onRejectOffer!(visibleOffers[index]),
          ),
          if (index != visibleOffers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OffersLoadingPanel extends StatelessWidget {
  const _OffersLoadingPanel({
    super.key,
    required this.ride,
    required this.route,
  });

  final ClientRide ride;
  final RouteResult? route;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _OfferReceivedHeader(
          title: 'Offres en chargement',
          subtitle: 'Les propositions des chauffeurs arrivent...',
          badgeLabel: 'Patientez',
        ),
        const SizedBox(height: 12),
        _CompactRideSummary(ride: ride, route: route),
        const SizedBox(height: 12),
        const _SearchingProgressCard(
          message: 'Chargement des offres...',
          isLoading: true,
        ),
      ],
    );
  }
}

class _OfferReceivedHeader extends StatelessWidget {
  const _OfferReceivedHeader({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.nigerOrangeSoft,
            border: Border.all(color: AppColors.nigerOrangeBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badgeLabel,
            style: const TextStyle(
              color: AppColors.nigerOrangeDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactRideSummary extends StatelessWidget {
  const _CompactRideSummary({
    required this.ride,
    required this.route,
  });

  final ClientRide ride;
  final RouteResult? route;

  @override
  Widget build(BuildContext context) {
    final hasReliableRoute = route != null && route!.hasReliableMetrics;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CompactRouteLabel(
                  label: 'Depart',
                  value: ride.pickupLocation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactRouteLabel(
                  label: 'Arrivee',
                  value: ride.dropoffLocation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactSummaryPill(
                  label: 'Prix client',
                  value: _formatFcfa(ride.displayPrice),
                ),
              ),
              if (hasReliableRoute) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactSummaryPill(
                    label: 'Trajet',
                    value:
                        '${route!.distanceKm.toStringAsFixed(1)} km - ${route!.durationMinutes} min',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatFcfa(double value) {
    if (!value.isFinite || value <= 0 || value > 500000) {
      return '--';
    }
    return '${value.round()} FCFA';
  }
}

class _CompactRouteLabel extends StatelessWidget {
  const _CompactRouteLabel({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _CompactSummaryPill extends StatelessWidget {
  const _CompactSummaryPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.nigerOrangeDark,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _SearchingRidePanel extends StatefulWidget {
  const _SearchingRidePanel({
    super.key,
    required this.ride,
    required this.route,
    this.nearbyDriversCount,
    this.onCancel,
  });

  final ClientRide ride;
  final RouteResult? route;
  final int? nearbyDriversCount;
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
    final helperText = _hasReliableProposedPrice
        ? 'Prix envoye aux chauffeurs'
        : 'Prix propose indisponible pour cette demande.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchingHeader(),
        const SizedBox(height: 12),
        RouteSummaryCard(
          pickupLabel: widget.ride.pickupLocation,
          dropoffLabel: widget.ride.dropoffLocation,
          distanceKm: widget.route?.distanceKm,
          durationMinutes: widget.route?.durationMinutes,
          isRouteReliable: widget.route?.hasReliableMetrics ?? false,
          reliabilityMessage: _routeReliabilityMessage,
        ),
        const SizedBox(height: 12),
        PriceSelector(
          controller: _proposedPriceController,
          enabled: false,
          compact: true,
          helperText: helperText,
        ),
        const SizedBox(height: 12),
        _SearchingProgressCard(
          message: _feedbackMessage,
          isLoading: widget.ride.status == 'pending',
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.error,
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            label: const Text('Annuler la demande'),
          ),
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
    final hasReliableRoute = route?.hasReliableMetrics ?? false;
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
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.nigerGreenSoft,
            border: Border.all(color: AppColors.nigerGreenBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'En cours',
            style: TextStyle(
              color: AppColors.nigerGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchingProgressCard extends StatelessWidget {
  const _SearchingProgressCard({
    required this.message,
    required this.isLoading,
  });

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.nigerOrangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.nigerOrangeBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.pearl,
              borderRadius: BorderRadius.circular(10),
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.nigerOrangeDark,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.check_rounded,
                    color: AppColors.nigerOrangeDark,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.nigerOrangeDark,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
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
    required this.pickupLocationQuality,
    required this.onTap,
    this.onClear,
  });

  final AddressResult? pickup;
  final LocationQuality pickupLocationQuality;
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
                  const SizedBox(height: 3),
                  if (_qualityLabel.isNotEmpty)
                    Text(
                      _qualityLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF757575),
                            fontWeight: FontWeight.w600,
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

  String get _qualityLabel {
    if (pickup == null) {
      return '';
    }
    if (!pickup!.isCurrentLocation) {
      return locationQualityLabel(LocationQuality.manual);
    }
    return locationQualityLabel(pickupLocationQuality);
  }
}

class _RecentAddressAction extends StatelessWidget {
  const _RecentAddressAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: Color(0xFF757575)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF757575),
            ),
          ],
        ),
      ),
    );
  }
}

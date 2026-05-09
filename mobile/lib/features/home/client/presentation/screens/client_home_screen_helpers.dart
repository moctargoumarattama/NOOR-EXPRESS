part of 'client_home_screen.dart';

extension _ClientHomeActions on _ClientHomeScreenState {
  void _listenToRealtime() {
    _realtimeSubscription = ref.listenManual<ClientRealtimeState>(
      clientRealtimeProvider,
      (previous, next) {
        if (!_isUiMounted) {
          return;
        }
        final position = next.lastDriverPosition;
        if (position != null && position != previous?.lastDriverPosition) {
          ref
              .read(mapControllerProvider(MapMode.client).notifier)
              .applyDriverPositionUpdate(position);
          ref.read(clientRealtimeProvider.notifier).consumeDriverPosition();
        }

        final message = next.lastMessage;
        if (message == null || message == previous?.lastMessage) {
          return;
        }
        final offerRideId = next.lastOfferRideId;
        if (offerRideId != null && offerRideId != previous?.lastOfferRideId) {
          final activeRide = ref.read(clientHomeControllerProvider).activeRide;
          if (activeRide?.id == offerRideId &&
              activeRide?.status == 'offered') {
            unawaited(
              _loadHomeOffers(
                offerRideId,
                force: true,
                keepExisting: true,
              ),
            );
          }
        }
        _showSnackBar(message);
        _showNotification(message);
        ref.read(clientRealtimeProvider.notifier).consumeMessage();
      },
    );
  }

  void _scheduleHomeOfferSync(ClientRide? ride) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isUiMounted) {
        return;
      }
      _syncHomeOffers(ride);
    });
  }

  void _syncHomeOffers(ClientRide? ride) {
    if (ride?.status != 'offered') {
      if (_homeOffersRideId != null ||
          _homeOffers.isNotEmpty ||
          _isLoadingHomeOffers) {
        _updateUi(() {
          _homeOffersRideId = null;
          _homeOffers = const [];
          _isLoadingHomeOffers = false;
          _acceptingHomeOfferId = null;
          _rejectingHomeOfferId = null;
        });
      }
      return;
    }

    if (_homeOffersRideId == ride!.id || _isLoadingHomeOffers) {
      return;
    }
    unawaited(_loadHomeOffers(ride.id));
  }

  Future<void> _loadHomeOffers(
    int rideId, {
    bool force = false,
    bool keepExisting = false,
  }) async {
    if (!_isUiMounted) {
      return;
    }
    if (!force && (_homeOffersRideId == rideId || _isLoadingHomeOffers)) {
      return;
    }
    _updateUi(() {
      _homeOffersRideId = rideId;
      if (!keepExisting) {
        _homeOffers = const [];
      }
      _isLoadingHomeOffers = true;
      _acceptingHomeOfferId = null;
      _rejectingHomeOfferId = null;
    });

    try {
      final offers = await ref
          .read(negotiationDatasourceProvider('client-home-offers'))
          .fetchOffers(rideId);
      offers.sort(
        (left, right) => left.proposedPrice.compareTo(right.proposedPrice),
      );
      if (!_isUiMounted) {
        return;
      }
      final activeRide = ref.read(clientHomeControllerProvider).activeRide;
      if (activeRide?.id != rideId) {
        return;
      }
      _updateUi(() {
        _homeOffers = offers;
        _isLoadingHomeOffers = false;
      });
    } on NegotiationFailure catch (error) {
      if (!_isUiMounted) {
        return;
      }
      _updateUi(() => _isLoadingHomeOffers = false);
      _showSnackBar(
        _humanizeMessage(
          error.message,
          fallback: 'Impossible de charger les offres pour le moment.',
        ),
        tone: AppSnackbarTone.error,
      );
    }
  }

  void _markPriceAsEdited() {
    if (!_isApplyingSuggestedPrice) {
      _priceManuallyEdited = true;
    }
  }

  void _schedulePriceEstimate() {
    _priceEstimateDebounce?.cancel();
    final pickup = _pickupAddress;
    final dropoff = _dropoffAddress;
    if (pickup == null || dropoff == null) {
      ref.read(clientHomeControllerProvider.notifier).clearPriceEstimate();
      return;
    }
    _priceEstimateDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!_isUiMounted) {
        return;
      }
      _estimateSuggestedPrice(pickup, dropoff);
    });
  }

  Future<PriceEstimate?> _estimateSuggestedPrice(
    AddressResult pickup,
    AddressResult dropoff,
  ) async {
    if (!_isUiMounted) {
      return null;
    }
    final estimate =
        await ref.read(clientHomeControllerProvider.notifier).estimatePrice(
              pickupLat: pickup.latitude,
              pickupLng: pickup.longitude,
              dropoffLat: dropoff.latitude,
              dropoffLng: dropoff.longitude,
            );
    if (!_isUiMounted || estimate == null) {
      return estimate;
    }
    if (!_hasReliableSuggestedPrice(estimate)) {
      if (!_priceManuallyEdited) {
        _isApplyingSuggestedPrice = true;
        _priceController.clear();
        _isApplyingSuggestedPrice = false;
      }
      return estimate;
    }
    if (_priceController.text.trim().isEmpty || !_priceManuallyEdited) {
      _isApplyingSuggestedPrice = true;
      _priceController.text = estimate.estimatedPrice.round().toString();
      _isApplyingSuggestedPrice = false;
      _priceManuallyEdited = false;
    }
    return estimate;
  }

  bool _hasReliableSuggestedPrice(PriceEstimate estimate) {
    return estimate.estimatedPrice.isFinite &&
        estimate.distanceKm.isFinite &&
        estimate.estimatedPrice > 0 &&
        estimate.estimatedPrice <= 500000 &&
        estimate.distanceKm > 0;
  }

  Future<void> _openAddressSearch(AddressSearchMode mode) async {
    final result = await context.push<AddressResult>(
      AppRoutes.addressSearchFor(
        mode == AddressSearchMode.pickup ? 'pickup' : 'dropoff',
      ),
    );
    if (!_isUiMounted || result == null) {
      return;
    }
    final selectedAddress = _manualizedAddress(result);
    _updateUi(() {
      if (mode == AddressSearchMode.pickup) {
        _pickupAddress = selectedAddress;
      } else {
        _pickupAddress ??= _currentPickupAddress();
        _dropoffAddress = selectedAddress;
      }
    });
    if (mode == AddressSearchMode.dropoff) {
      await _prepareRideAfterDestinationSelected();
      return;
    }
    _schedulePriceEstimate();
  }

  AddressResult? _currentPickupAddress() {
    final position =
        ref.read(mapControllerProvider(MapMode.client)).currentPosition;
    if (position != null) {
      final quality = locationQualityFromAccuracy(position.accuracyMeters);
      if (quality == LocationQuality.unknown) {
        return null;
      }
      return AddressResult(
        name: 'Ma position actuelle',
        displayName: locationQualityLabel(quality),
        latitude: position.latitude,
        longitude: position.longitude,
        type: 'current_location',
        locationQuality: quality,
        accuracyMeters: position.accuracyMeters,
      );
    }
    return null;
  }

  Future<void> _prepareRideAfterDestinationSelected() async {
    final pickup = _pickupAddress;
    final dropoff = _dropoffAddress;
    if (pickup == null || dropoff == null) {
      return;
    }
    await _estimateSuggestedPrice(pickup, dropoff);
  }

  Future<void> _selectQuickDestination(AddressResult dropoff) async {
    _updateUi(() {
      _pickupAddress ??= _currentPickupAddress();
      _dropoffAddress = _manualizedAddress(dropoff);
    });
    await _prepareRideAfterDestinationSelected();
  }

  Future<void> _addDropoffToFavorites(AddressResult dropoff) async {
    final initialLabel = _initialFavoriteLabel(dropoff);
    final label = await _askFavoriteLabel(initialLabel);
    if (label == null) {
      return;
    }

    try {
      await ref.read(addressSearchControllerProvider.notifier).addFavorite(
            address: dropoff,
            label: label,
          );
      if (!_isUiMounted) {
        return;
      }
      _showSnackBar(
        'Adresse ajoutee aux favoris.',
        tone: AppSnackbarTone.success,
      );
    } on AddressSearchFailure catch (error) {
      if (!_isUiMounted) {
        return;
      }
      _showSnackBar(
        _humanizeMessage(
          error.message,
          fallback: 'Impossible d ajouter cette adresse aux favoris.',
        ),
        tone: AppSnackbarTone.error,
      );
    }
  }

  String _initialFavoriteLabel(AddressResult dropoff) {
    final name = dropoff.name.trim();
    return name.isEmpty ? 'Favori' : name;
  }

  Future<String?> _askFavoriteLabel(String initialLabel) async {
    final controller = TextEditingController(text: initialLabel);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _buildFavoriteLabelDialog(
        dialogContext,
        controller,
      ),
    );
    controller.dispose();
    final label = result?.trim();
    if (label == null || label.isEmpty) {
      return null;
    }
    return label;
  }

  AlertDialog _buildFavoriteLabelDialog(
    BuildContext dialogContext,
    TextEditingController controller,
  ) {
    return AlertDialog(
      title: const Text('Ajouter aux favoris'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Nom du favori',
          hintText: 'Maison, Bureau...',
        ),
        onSubmitted: (_) => _submitFavoriteLabel(dialogContext, controller),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => _submitFavoriteLabel(dialogContext, controller),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }

  void _submitFavoriteLabel(
    BuildContext dialogContext,
    TextEditingController controller,
  ) {
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      Navigator.of(dialogContext).pop(value);
    }
  }

  Future<void> _submitRide() async {
    final currentState = ref.read(clientHomeControllerProvider);
    final currentActiveRide = currentState.activeRide;
    if (shouldBlockClientRideCreation(currentActiveRide)) {
      await _resumeExistingRide(currentActiveRide!);
      return;
    }

    final input = _buildRideInput();
    if (input == null) {
      return;
    }
    final success =
        await ref.read(clientHomeControllerProvider.notifier).createRide(input);
    if (!_isUiMounted) {
      return;
    }

    final nextState = ref.read(clientHomeControllerProvider);
    if (!success) {
      if (shouldRecoverExistingRideFromCreateError(nextState.createErrorCode)) {
        await _recoverExistingRideAfterCreateConflict();
        return;
      }
      if (nextState.createErrorCode == 'ride_request_temporarily_blocked') {
        _showSnackBar(
          _humanizeMessage(
            nextState.createError,
            fallback:
                'Blocage temporaire actif. Reessayez plus tard pour creer une course.',
          ),
          tone: AppSnackbarTone.info,
        );
        return;
      }

      _showSnackBar(
        _humanizeMessage(
          nextState.createError,
          fallback: 'Impossible d envoyer la demande pour le moment.',
        ),
        tone: AppSnackbarTone.error,
      );
      return;
    }
    final createdRideId = nextState.rides.first.id;
    final routeSnapshot = ref.read(noorMapControllerProvider).route;
    _updateUi(() {
      _activeRideRouteSnapshotRideId = createdRideId;
      _activeRideRouteSnapshot = routeSnapshot;
    });
    _resetForm();
    _showSnackBar(
      'Votre demande est envoyee. On cherche un chauffeur.',
      tone: AppSnackbarTone.success,
    );
  }

  Future<void> _resumeExistingRide(
    ClientRide ride, {
    String? message,
  }) async {
    _showSnackBar(
      message ?? activeRideResumeMessage(ride),
      tone: AppSnackbarTone.info,
    );
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!_isUiMounted) {
      return;
    }
    _openRide(ride);
  }

  Future<void> _cancelActiveRide(ClientRide? ride) async {
    if (ride == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Annuler la demande ?'),
          content: const Text(
            'Votre proposition sera retiree et les chauffeurs ne pourront '
            'plus y repondre.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Garder'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Annuler la demande'),
            ),
          ],
        );
      },
    );
    if (!mounted || !_isUiMounted || confirmed != true) {
      return;
    }

    final cancellationDraft = await showRideCancellationBottomSheet(
      context,
      title: 'Pourquoi annuler la demande ?',
      confirmLabel: 'Confirmer l annulation',
      options: passengerCancellationReasonOptions,
      reasonRequired: false,
    );
    if (!_isUiMounted || cancellationDraft == null) {
      return;
    }

    try {
      await ref
          .read(negotiationDatasourceProvider('client-home-cancel'))
          .cancelRide(
            ride.id,
            reason: cancellationDraft.reason,
            reasonCode: cancellationDraft.reasonCode,
          );
      if (!_isUiMounted) {
        return;
      }
      await ref.read(clientHomeControllerProvider.notifier).refreshRideStatus(
            rideId: ride.id,
            status: 'cancelled',
          );
      if (!_isUiMounted) {
        return;
      }
      _updateUi(() {
        if (_activeRideRouteSnapshotRideId == ride.id) {
          _activeRideRouteSnapshotRideId = null;
          _activeRideRouteSnapshot = null;
        }
        if (_homeOffersRideId == ride.id) {
          _homeOffersRideId = null;
          _homeOffers = const [];
          _acceptingHomeOfferId = null;
          _rejectingHomeOfferId = null;
        }
      });
      _showSnackBar('Demande annulee.', tone: AppSnackbarTone.success);
    } on NegotiationFailure catch (error) {
      if (!_isUiMounted) {
        return;
      }
      _showSnackBar(
        _humanizeMessage(
          error.message,
          fallback: 'Impossible d annuler la demande pour le moment.',
        ),
        tone: AppSnackbarTone.error,
      );
    }
  }

  Future<void> _acceptHomeOffer(RideOfferModel offer) async {
    final ride = ref.read(clientHomeControllerProvider).activeRide;
    if (ride == null || _acceptingHomeOfferId != null) {
      return;
    }
    _updateUi(() {
      _acceptingHomeOfferId = offer.offerId;
      _rejectingHomeOfferId = null;
    });

    try {
      await ref
          .read(negotiationDatasourceProvider('client-home-offers'))
          .acceptOffer(offer.offerId);
      if (!_isUiMounted) {
        return;
      }
      final activeRide = await _resyncHomeTruth();
      if (!_isUiMounted) {
        return;
      }
      if (activeRide != null &&
          activeRide.id == ride.id &&
          _isTrackingRideStatus(activeRide)) {
        if (!mounted) {
          return;
        }
        context.go(AppRoutes.clientMapWithRide(ride.id));
        return;
      }
      _updateUi(() => _acceptingHomeOfferId = null);
      _showSnackBar(
        'Offre traitee. On remet votre demande a jour.',
        tone: AppSnackbarTone.info,
      );
    } on NegotiationFailure catch (error) {
      if (!_isUiMounted) {
        return;
      }
      _updateUi(() => _acceptingHomeOfferId = null);
      _showSnackBar(
        _humanizeMessage(
          error.message,
          fallback: 'Impossible d accepter cette offre pour le moment.',
        ),
        tone: AppSnackbarTone.error,
      );
    }
  }

  Future<void> _rejectHomeOffer(RideOfferModel offer) async {
    if (_rejectingHomeOfferId != null || _acceptingHomeOfferId != null) {
      return;
    }
    final rideId = ref.read(clientHomeControllerProvider).activeRide?.id;
    _updateUi(() {
      _rejectingHomeOfferId = offer.offerId;
      _acceptingHomeOfferId = null;
    });

    try {
      await ref
          .read(negotiationDatasourceProvider('client-home-offers'))
          .rejectOffer(offer.offerId);
      if (!_isUiMounted) {
        return;
      }
      final activeRide = await _resyncHomeTruth();
      if (!_isUiMounted) {
        return;
      }
      if (activeRide?.id == rideId && activeRide?.status == 'offered') {
        await _loadHomeOffers(activeRide!.id, force: true);
      } else {
        _updateUi(() {
          _homeOffersRideId = null;
          _homeOffers = const [];
          _rejectingHomeOfferId = null;
        });
      }
      _showSnackBar('Offre refusee.', tone: AppSnackbarTone.info);
    } on NegotiationFailure catch (error) {
      if (!_isUiMounted) {
        return;
      }
      _updateUi(() => _rejectingHomeOfferId = null);
      _showSnackBar(
        _humanizeMessage(
          error.message,
          fallback: 'Impossible de refuser cette offre pour le moment.',
        ),
        tone: AppSnackbarTone.error,
      );
    }
  }

  Future<void> _recoverExistingRideAfterCreateConflict() async {
    await ref.read(clientHomeControllerProvider.notifier).loadRides();
    if (!_isUiMounted) {
      return;
    }

    final activeRide = ref.read(clientHomeControllerProvider).activeRide;
    if (shouldBlockClientRideCreation(activeRide)) {
      await _resumeExistingRide(activeRide!);
      return;
    }

    _showSnackBar(
      RideUiCopy.activeRideConflict,
      tone: AppSnackbarTone.info,
    );
  }

  RideRequestCreateInput? _buildRideInput() {
    final pickup = _pickupAddress;
    final dropoff = _dropoffAddress;
    final mapState = ref.read(mapControllerProvider(MapMode.client));
    final pickupQuality = _resolvedPickupLocationQuality(mapState);
    final price = double.tryParse(_priceController.text.trim());
    if (pickup == null || dropoff == null) {
      if (pickupQuality == LocationQuality.unknown) {
        _showSnackBar(
          'Position non disponible. Saisissez votre adresse de depart manuellement.',
          tone: AppSnackbarTone.error,
        );
        return null;
      }
      _showSnackBar(
        'Choisissez votre depart et votre arrivee.',
        tone: AppSnackbarTone.error,
      );
      return null;
    }
    if (_priceController.text.trim().isNotEmpty &&
        (price == null || price <= 0)) {
      _showSnackBar('Entrez un prix valide.', tone: AppSnackbarTone.error);
      return null;
    }
    return RideRequestCreateInput(
      pickupLocation: pickup.name,
      dropoffLocation: dropoff.name,
      clientLatitude: pickup.latitude,
      clientLongitude: pickup.longitude,
      dropoffLatitude: dropoff.latitude,
      dropoffLongitude: dropoff.longitude,
      estimatedPrice: price,
    );
  }

  void _clearPickup() {
    _updateUi(() => _pickupAddress = null);
    _schedulePriceEstimate();
  }

  void _clearDropoff() {
    _updateUi(() => _dropoffAddress = null);
    _schedulePriceEstimate();
  }

  void _resetForm() {
    _priceEstimateDebounce?.cancel();
    _updateUi(() {
      _pickupAddress = null;
      _dropoffAddress = null;
    });
    _priceController.clear();
    _priceManuallyEdited = false;
    ref.read(clientHomeControllerProvider.notifier).clearPriceEstimate();
  }

  void _openRide(ClientRide? ride) {
    if (ride == null) {
      return;
    }
    if (ride.status == 'pending' || ride.status == 'offered') {
      context.push(AppRoutes.clientNegotiation(ride.id));
    } else {
      context.go(AppRoutes.clientMapWithRide(ride.id));
    }
  }

  Future<ClientRide?> _resyncHomeTruth() async {
    await ref.read(clientHomeControllerProvider.notifier).resumeFromLifecycle();
    if (!_isUiMounted) {
      return null;
    }
    return ref.read(clientHomeControllerProvider).activeRide;
  }

  AddressResult _manualizedAddress(AddressResult result) {
    if (result.isCurrentLocation) {
      return result;
    }
    return result.copyWith(
      locationQuality: LocationQuality.manual,
      clearAccuracyMeters: true,
    );
  }

  LocationQuality _resolvedPickupLocationQuality(MapState mapState) {
    final pickup = _pickupAddress;
    if (pickup == null) {
      return locationQualityFromAccuracy(mapState.currentPosition?.accuracyMeters);
    }
    if (!pickup.isCurrentLocation) {
      return LocationQuality.manual;
    }
    final liveQuality =
        locationQualityFromAccuracy(mapState.currentPosition?.accuracyMeters);
    if (liveQuality != LocationQuality.unknown) {
      return liveQuality;
    }
    final explicitQuality = pickup.locationQuality;
    if (explicitQuality != null && explicitQuality != LocationQuality.unknown) {
      return explicitQuality;
    }
    return LocationQuality.unknown;
  }

  double? _resolvedPickupAccuracyMeters(MapState mapState) {
    final pickup = _pickupAddress;
    if (pickup == null || !pickup.isCurrentLocation) {
      return mapState.currentPosition?.accuracyMeters;
    }
    return mapState.currentPosition?.accuracyMeters ?? pickup.accuracyMeters;
  }

  bool _shouldShowUnknownPositionCard(
    ClientRide? activeRide,
    LocationQuality pickupQuality,
  ) {
    if (activeRide != null) {
      return false;
    }
    if (_pickupAddress != null) {
      return false;
    }
    return pickupQuality == LocationQuality.unknown;
  }

  bool _shouldShowApproximateBanner(
    ClientRide? activeRide,
    LocationQuality pickupQuality,
  ) {
    if (activeRide != null) {
      return false;
    }
    return pickupQuality == LocationQuality.approximate;
  }

  String? _submitDisabledReasonForQuality(LocationQuality quality) {
    if (quality != LocationQuality.unknown) {
      return null;
    }
    return 'Position non disponible. Recherchez votre adresse de depart manuellement.';
  }

  bool _isTrackingRideStatus(ClientRide ride) {
    return ride.status == 'accepted' ||
        ride.status == 'arrived' ||
        ride.status == 'started';
  }

  Future<void> _openGeneralReport() async {
    _updateUi(() => _isMenuOpen = false);
    final activeRide = ref.read(clientHomeControllerProvider).activeRide;
    final trackingDatasource = ref.read(trackingRemoteDatasourceProvider);
    final draft = await showRideReportBottomSheet(
      context,
      onSubmit: (draft) async {
        if (activeRide == null) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          return;
        }
        await trackingDatasource.reportRide(
              rideId: activeRide.id,
              reason: draft.reason,
              description: draft.description,
            );
      },
    );
    if (_isUiMounted && draft != null) {
      _showSnackBar('Signalement envoye.', tone: AppSnackbarTone.success);
    }
  }

  List<String> _recentDepartureLabels(List<ClientRide> rides) {
    final sortedRides = [...rides]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final labels = <String>[];

    for (final ride in sortedRides) {
      final label = ride.pickupLocation.trim();
      if (label.isEmpty || labels.contains(label)) {
        continue;
      }
      labels.add(label);
      if (labels.length == 3) {
        break;
      }
    }

    return labels;
  }

  void _showSnackBar(String message, {AppSnackbarTone? tone}) {
    final humanized = _humanizeMessage(message, fallback: message);
    AppSnackbar.show(
      context,
      message: humanized,
      tone: tone ?? _snackbarToneForMessage(humanized),
    );
  }

  void _showNotification(String message) {
    _updateUi(() => _notificationMessage = _humanizeMessage(message));
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 4), () {
      _updateUi(() => _notificationMessage = null);
    });
  }

  AppSnackbarTone _snackbarToneForMessage(String message) {
    final value = message.toLowerCase();
    if (value.contains('terminee') || value.contains('succes')) {
      return AppSnackbarTone.success;
    }
    if (value.contains('annulee') ||
        value.contains('indisponible') ||
        value.contains('impossible')) {
      return AppSnackbarTone.error;
    }
    if (value.contains('reconnexion') ||
        value.contains('connexion') ||
        value.contains('chauffeur')) {
      return AppSnackbarTone.info;
    }
    return AppSnackbarTone.info;
  }

  NotificationCardTone _notificationToneForMessage(String message) {
    final value = message.toLowerCase();
    if (value.contains('terminee') || value.contains('confirme')) {
      return NotificationCardTone.success;
    }
    if (value.contains('annulee') || value.contains('indisponible')) {
      return NotificationCardTone.error;
    }
    if (value.contains('reconnexion') || value.contains('chauffeur')) {
      return NotificationCardTone.warning;
    }
    return NotificationCardTone.info;
  }

  String _humanizeMessage(String? message, {String? fallback}) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback ?? '';
    }

    final value = trimmed.toLowerCase();
    if (value.contains('gps')) {
      return RideUiCopy.gpsUnavailable;
    }
    if (value.contains('network') ||
        value.contains('connexion') ||
        value.contains('socket') ||
        value.contains('timeout')) {
      return RideUiCopy.networkError;
    }
    if ((value.contains('aucun') && value.contains('chauffeur')) ||
        value.contains('no driver')) {
      return RideUiCopy.noDriverAvailable;
    }
    if (value.contains('expire')) {
      return RideUiCopy.offerExpired;
    }
    if (value.contains('course annulee') ||
        value.contains('trajet a ete annule')) {
      return RideUiCopy.rideCancelled;
    }
    if (value.contains('indisponible') && value.contains('chauffeur')) {
      return RideUiCopy.driverUnavailable;
    }

    return trimmed;
  }

  String _displayName(SessionState session) {
    final name = session.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return session.phoneNumber ?? 'Client Noor';
  }

  String _initials(String value) {
    final words = value.split(' ').where((part) => part.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words.first[0]}${words[1][0]}'.toUpperCase();
    }
    return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
  }
}

part of 'client_home_screen.dart';

extension _ClientHomeActions on _ClientHomeScreenState {
  void _listenToRealtime() {
    _realtimeSubscription = ref.listenManual<ClientRealtimeState>(
      clientRealtimeProvider,
      (previous, next) {
        final position = next.lastDriverPosition;
        if (position != null && position != previous?.lastDriverPosition) {
          ref
              .read(mapControllerProvider(MapMode.client).notifier)
              .applyDriverPositionUpdate(position);
          ref.read(clientRealtimeProvider.notifier).consumeDriverPosition();
        }

        final message = next.lastMessage;
        if (message == null || message == previous?.lastMessage || !mounted) {
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
      if (!mounted) {
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
      if (!mounted) {
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
      if (!mounted) {
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
      _estimateSuggestedPrice(pickup, dropoff);
    });
  }

  Future<PriceEstimate?> _estimateSuggestedPrice(
    AddressResult pickup,
    AddressResult dropoff,
  ) async {
    final estimate =
        await ref.read(clientHomeControllerProvider.notifier).estimatePrice(
              pickupLat: pickup.latitude,
              pickupLng: pickup.longitude,
              dropoffLat: dropoff.latitude,
              dropoffLng: dropoff.longitude,
            );
    if (!mounted || estimate == null) {
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
    if (!mounted || result == null) {
      return;
    }
    _updateUi(() {
      if (mode == AddressSearchMode.pickup) {
        _pickupAddress = result;
      } else {
        _pickupAddress ??= _currentPickupAddress();
        _dropoffAddress = result;
      }
    });
    if (mode == AddressSearchMode.dropoff) {
      await _prepareRideAfterDestinationSelected();
      return;
    }
    _schedulePriceEstimate();
  }

  AddressResult _currentPickupAddress() {
    final position =
        ref.read(mapControllerProvider(MapMode.client)).currentPosition;
    if (position != null) {
      return AddressResult(
        name: 'Ma position actuelle',
        displayName: 'Ma position actuelle',
        latitude: position.latitude,
        longitude: position.longitude,
        type: 'current_location',
      );
    }
    return const AddressResult(
      name: 'Niamey centre',
      displayName: 'Position approximative',
      latitude: 13.5137,
      longitude: 2.1098,
      type: 'current_location',
    );
  }

  Future<void> _prepareRideAfterDestinationSelected() async {
    final pickup = _pickupAddress;
    final dropoff = _dropoffAddress;
    if (pickup == null || dropoff == null) {
      return;
    }
    await _estimateSuggestedPrice(pickup, dropoff);
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
    if (!mounted) {
      return;
    }

    final nextState = ref.read(clientHomeControllerProvider);
    if (!success) {
      if (shouldRecoverExistingRideFromCreateError(nextState.createErrorCode)) {
        await _recoverExistingRideAfterCreateConflict();
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
    if (!mounted) {
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
    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await ref
          .read(negotiationDatasourceProvider('client-home-cancel'))
          .cancelRide(ride.id);
      if (!mounted) {
        return;
      }
      await ref.read(clientHomeControllerProvider.notifier).refreshRideStatus(
            rideId: ride.id,
            status: 'cancelled',
          );
      if (!mounted) {
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
      if (!mounted) {
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
      if (!mounted) {
        return;
      }
      final activeRide = await _resyncHomeTruth();
      if (!mounted) {
        return;
      }
      if (activeRide != null &&
          activeRide.id == ride.id &&
          _isTrackingRideStatus(activeRide)) {
        context.go(AppRoutes.clientMapWithRide(ride.id));
        return;
      }
      _updateUi(() => _acceptingHomeOfferId = null);
      _showSnackBar(
        'Offre traitee. On remet votre demande a jour.',
        tone: AppSnackbarTone.info,
      );
    } on NegotiationFailure catch (error) {
      if (!mounted) {
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
      if (!mounted) {
        return;
      }
      final activeRide = await _resyncHomeTruth();
      if (!mounted) {
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
      if (!mounted) {
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
    if (!mounted) {
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
    final price = double.tryParse(_priceController.text.trim());
    if (pickup == null || dropoff == null) {
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
    return ref.read(clientHomeControllerProvider).activeRide;
  }

  bool _isTrackingRideStatus(ClientRide ride) {
    return ride.status == 'accepted' ||
        ride.status == 'arrived' ||
        ride.status == 'started';
  }

  Future<void> _openGeneralReport() async {
    _updateUi(() => _isMenuOpen = false);
    final activeRide = ref.read(clientHomeControllerProvider).activeRide;
    final draft = await showRideReportBottomSheet(
      context,
      onSubmit: (draft) async {
        if (activeRide == null) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          return;
        }
        await ref.read(trackingRemoteDatasourceProvider).reportRide(
              rideId: activeRide.id,
              reason: draft.reason,
              description: draft.description,
            );
      },
    );
    if (mounted && draft != null) {
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
    if (value.contains('annul')) {
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

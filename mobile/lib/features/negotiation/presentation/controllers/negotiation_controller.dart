import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/websocket_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../data/datasources/negotiation_datasource.dart';
import '../../data/models/ride_offer_model.dart';
import '../../domain/entities/negotiation_state.dart';

class NegotiationScope {
  const NegotiationScope({
    required this.mode,
    required this.rideId,
    this.initialRide,
  });

  final NegotiationMode mode;
  final int rideId;
  final NegotiationRideModel? initialRide;

  @override
  bool operator ==(Object other) {
    return other is NegotiationScope &&
        other.mode == mode &&
        other.rideId == rideId;
  }

  @override
  int get hashCode => Object.hash(mode, rideId);
}

class NegotiationController extends StateNotifier<NegotiationState> {
  NegotiationController({
    required this.ref,
    required this.scope,
    required NegotiationDatasource datasource,
  })  : _datasource = datasource,
        super(NegotiationState.initial(mode: scope.mode, rideId: scope.rideId));

  final Ref ref;
  final NegotiationScope scope;
  final NegotiationDatasource _datasource;

  StreamSubscription<NegotiationSocketEvent>? _eventSubscription;
  StreamSubscription<WebSocketStatus>? _statusSubscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    if (scope.initialRide != null) {
      state = state.copyWith(ride: scope.initialRide);
    }

    state = state.copyWith(isLoading: true, clearError: true);
    await _loadRide();
    if (scope.mode == NegotiationMode.client) {
      await _loadOffers();
    }
    await _bindRealtime();
    state = state.copyWith(isLoading: false);
  }

  Future<void> stop() async {
    _started = false;
    await _eventSubscription?.cancel();
    await _statusSubscription?.cancel();
    _eventSubscription = null;
    _statusSubscription = null;
    await _datasource.disconnect();
  }

  Future<void> refresh() async {
    await _loadRide();
    if (scope.mode == NegotiationMode.client) {
      await _loadOffers();
    }
  }

  Future<void> submitOffer(double proposedPrice) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final offer = await _datasource.createOffer(
        rideId: scope.rideId,
        proposedPrice: proposedPrice,
      );
      state = state.copyWith(
        isSubmitting: false,
        hasSubmittedOffer: true,
        submittedPrice: offer.proposedPrice,
        offers: [offer],
        toastMessage: 'Offre envoyee, en attente de reponse...',
      );
    } on NegotiationFailure catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    }
  }

  Future<void> acceptOffer(int offerId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _datasource.acceptOffer(offerId);
      state = state.copyWith(
        isSubmitting: false,
        toastMessage: 'Driver selectionne.',
        navigateToTrackingRideId: scope.rideId,
      );
    } on NegotiationFailure catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    }
  }

  Future<void> rejectOffer(int offerId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _datasource.rejectOffer(offerId);
      state = state.copyWith(
        isSubmitting: false,
        offers:
            state.offers.where((offer) => offer.offerId != offerId).toList(),
        toastMessage: 'Offre refusee.',
      );
    } on NegotiationFailure catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    }
  }

  Future<void> cancelRide({String? reason}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _datasource.cancelRide(scope.rideId, reason: reason);
      state = state.copyWith(
        isSubmitting: false,
        toastMessage: 'Demande annulee.',
        shouldCloseToHome: true,
      );
    } on NegotiationFailure catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    }
  }

  void consumeToast() => state = state.copyWith(clearToast: true);
  void consumeNavigation() => state = state.copyWith(clearNavigation: true);
  void consumeCloseAction() => state = state.copyWith(shouldCloseToHome: false);

  Future<void> _bindRealtime() async {
    final userId = ref.read(sessionControllerProvider).userId;
    if (userId == null) {
      return;
    }

    _statusSubscription = _datasource.statuses.listen((status) {
      state = state.copyWith(connectionState: _mapConnectionStatus(status));
    });
    _eventSubscription = _datasource.events.listen(_handleSocketEvent);

    if (scope.mode == NegotiationMode.client) {
      await _datasource.connectClient(userId);
    } else {
      await _datasource.connectDriver(userId);
    }
  }

  void _handleSocketEvent(NegotiationSocketEvent event) {
    if (event.rideId != scope.rideId) {
      return;
    }

    switch (event.type) {
      case NegotiationSocketEventType.newOffer:
        final offer = event.offer;
        if (offer == null || scope.mode != NegotiationMode.client) {
          return;
        }
        state = state.copyWith(
          offers: _upsertOffer(offer),
          toastMessage: 'Nouvelle proposition recue.',
        );
        return;
      case NegotiationSocketEventType.offerAccepted:
        state = state.copyWith(
          toastMessage: 'Votre offre a ete acceptee.',
          navigateToTrackingRideId: scope.rideId,
        );
        return;
      case NegotiationSocketEventType.offerRejected:
        state = state.copyWith(
          toastMessage: 'Votre offre n a pas ete retenue.',
          shouldCloseToHome: true,
        );
        return;
      case NegotiationSocketEventType.rideStatus:
        final ride = state.ride;
        state = state.copyWith(
          ride: ride?.copyWith(status: event.status ?? ride.status),
        );
        if (event.status == 'accepted') {
          state = state.copyWith(navigateToTrackingRideId: scope.rideId);
        }
        if (event.status == 'cancelled' || event.status == 'expired') {
          state = state.copyWith(shouldCloseToHome: true);
        }
        return;
    }
  }

  Future<void> _loadRide() async {
    try {
      final ride = scope.mode == NegotiationMode.client
          ? await _datasource.fetchClientRide(scope.rideId)
          : await _datasource.fetchDriverCandidateRide(scope.rideId);
      state = state.copyWith(ride: ride, clearError: true);
    } on NegotiationFailure catch (error) {
      if (state.ride == null) {
        state = state.copyWith(errorMessage: error.message);
      }
    }
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _datasource.fetchOffers(scope.rideId);
      state = state.copyWith(offers: offers, clearError: true);
    } on NegotiationFailure catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  List<RideOfferModel> _upsertOffer(RideOfferModel nextOffer) {
    final updated = [...state.offers];
    final index =
        updated.indexWhere((offer) => offer.offerId == nextOffer.offerId);
    if (index >= 0) {
      updated[index] = nextOffer;
    } else {
      updated.insert(0, nextOffer);
    }
    updated.sort(
        (left, right) => left.proposedPrice.compareTo(right.proposedPrice));
    return updated;
  }

  NegotiationConnectionState _mapConnectionStatus(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.connected:
        return NegotiationConnectionState.connected;
      case WebSocketStatus.connecting:
        return NegotiationConnectionState.connecting;
      case WebSocketStatus.reconnecting:
        return NegotiationConnectionState.reconnecting;
      case WebSocketStatus.disconnected:
        return NegotiationConnectionState.disconnected;
    }
  }
}

final negotiationControllerProvider = StateNotifierProvider.autoDispose
    .family<NegotiationController, NegotiationState, NegotiationScope>(
        (ref, scope) {
  final controller = NegotiationController(
    ref: ref,
    scope: scope,
    datasource: ref.watch(negotiationDatasourceProvider(scope.mode.name)),
  );
  ref.onDispose(() {
    controller.stop();
  });
  return controller;
});

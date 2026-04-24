import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/client_rides_repository.dart';
import '../../data/models/client_ride.dart';

class ClientHomeState {
  const ClientHomeState({
    required this.rides,
    this.activeRide,
    required this.isLoading,
    required this.isCreating,
    required this.isEstimatingPrice,
    this.loadError,
    this.createError,
    this.createErrorCode,
    this.priceEstimate,
    this.priceEstimateError,
  });

  const ClientHomeState.initial()
      : this(
          rides: const [],
          isLoading: false,
          isCreating: false,
          isEstimatingPrice: false,
        );

  final List<ClientRide> rides;
  final ClientRide? activeRide;
  final bool isLoading;
  final bool isCreating;
  final bool isEstimatingPrice;
  final String? loadError;
  final String? createError;
  final String? createErrorCode;
  final PriceEstimate? priceEstimate;
  final String? priceEstimateError;

  ClientHomeState copyWith({
    List<ClientRide>? rides,
    ClientRide? activeRide,
    bool? isLoading,
    bool? isCreating,
    bool? isEstimatingPrice,
    String? loadError,
    String? createError,
    String? createErrorCode,
    PriceEstimate? priceEstimate,
    String? priceEstimateError,
    bool clearLoadError = false,
    bool clearCreateError = false,
    bool clearPriceEstimate = false,
    bool clearPriceEstimateError = false,
    bool clearActiveRide = false,
  }) {
    return ClientHomeState(
      rides: rides ?? this.rides,
      activeRide: clearActiveRide ? null : activeRide ?? this.activeRide,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isEstimatingPrice: isEstimatingPrice ?? this.isEstimatingPrice,
      loadError: clearLoadError ? null : loadError ?? this.loadError,
      createError: clearCreateError ? null : createError ?? this.createError,
      createErrorCode:
          clearCreateError ? null : createErrorCode ?? this.createErrorCode,
      priceEstimate:
          clearPriceEstimate ? null : priceEstimate ?? this.priceEstimate,
      priceEstimateError: clearPriceEstimateError
          ? null
          : priceEstimateError ?? this.priceEstimateError,
    );
  }
}

class ClientHomeController extends StateNotifier<ClientHomeState> {
  ClientHomeController({
    required ClientRidesRepository repository,
  })  : _repository = repository,
        super(const ClientHomeState.initial());

  final ClientRidesRepository _repository;

  Future<void> loadRides() async {
    state = state.copyWith(
      isLoading: true,
      clearLoadError: true,
    );

    try {
      final rides = await _repository.fetchMyRides();
      final activeRide = await _repository.fetchActiveRide();
      state = state.copyWith(
        rides: rides,
        activeRide: activeRide,
        isLoading: false,
        clearLoadError: true,
      );
    } on ClientRideFailure catch (error) {
      state = state.copyWith(
        isLoading: false,
        loadError: error.message,
      );
    }
  }

  Future<void> resumeFromLifecycle() async {
    try {
      final rides = await _repository.fetchMyRides();
      final activeRide = await _repository.fetchActiveRide();
      state = state.copyWith(
        rides: rides,
        activeRide: activeRide,
        clearLoadError: true,
      );
    } on ClientRideFailure catch (error) {
      if (state.rides.isEmpty) {
        state = state.copyWith(loadError: error.message);
      }
    }
  }

  Future<bool> createRide(RideRequestCreateInput input) async {
    state = state.copyWith(
      isCreating: true,
      clearCreateError: true,
    );

    try {
      final ride = await _repository.createRide(input);
      state = state.copyWith(
        isCreating: false,
        rides: [ride, ...state.rides],
        activeRide: ride,
        clearCreateError: true,
      );
      return true;
    } on ClientRideFailure catch (error) {
      state = state.copyWith(
        isCreating: false,
        createError: error.message,
        createErrorCode: error.code,
      );
      return false;
    }
  }

  Future<PriceEstimate?> estimatePrice({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    state = state.copyWith(
      isEstimatingPrice: true,
      clearPriceEstimateError: true,
    );

    try {
      final estimate = await _repository.getPriceEstimate(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
      state = state.copyWith(
        isEstimatingPrice: false,
        priceEstimate: estimate,
        clearPriceEstimateError: true,
      );
      return estimate;
    } on ClientRideFailure catch (error) {
      state = state.copyWith(
        isEstimatingPrice: false,
        priceEstimateError: error.message,
      );
      return null;
    }
  }

  void clearPriceEstimate() {
    state = state.copyWith(
      clearPriceEstimate: true,
      clearPriceEstimateError: true,
    );
  }

  Future<void> refreshRideStatus({
    required int rideId,
    required String status,
  }) async {
    final index = state.rides.indexWhere((ride) => ride.id == rideId);
    if (index < 0) {
      await loadRides();
      return;
    }

    final updated = [...state.rides];
    final nextRide = updated[index].copyWith(status: status);
    updated[index] = nextRide;
    final currentActiveRide = state.activeRide;
    final shouldClearActiveRide = switch (status) {
      'completed' || 'cancelled' || 'expired' => true,
      _ => false,
    };
    final shouldPromoteUpdatedRide =
        currentActiveRide == null || currentActiveRide.id == rideId;
    state = state.copyWith(
      rides: updated,
      activeRide: shouldPromoteUpdatedRide && !shouldClearActiveRide
          ? nextRide
          : currentActiveRide,
      clearActiveRide: shouldPromoteUpdatedRide && shouldClearActiveRide,
    );
  }
}

final clientHomeControllerProvider =
    StateNotifierProvider<ClientHomeController, ClientHomeState>((ref) {
  return ClientHomeController(
    repository: ref.watch(clientRidesRepositoryProvider),
  );
});

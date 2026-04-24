import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/driver_rides_repository.dart';
import '../../data/models/driver_ride.dart';

class RideDriverState {
  const RideDriverState({
    required this.availableRides,
    required this.rides,
    required this.isLoadingAvailable,
    required this.isLoadingHistory,
    required this.isSubmittingAction,
    this.activeRideId,
    this.activeAction,
    this.availableErrorMessage,
    this.historyErrorMessage,
  });

  const RideDriverState.initial()
      : this(
          availableRides: const [],
          rides: const [],
          isLoadingAvailable: false,
          isLoadingHistory: false,
          isSubmittingAction: false,
        );

  final List<DriverRide> availableRides;
  final List<DriverRide> rides;
  final bool isLoadingAvailable;
  final bool isLoadingHistory;
  final bool isSubmittingAction;
  final int? activeRideId;
  final String? activeAction;
  final String? availableErrorMessage;
  final String? historyErrorMessage;

  RideDriverState copyWith({
    List<DriverRide>? availableRides,
    List<DriverRide>? rides,
    bool? isLoadingAvailable,
    bool? isLoadingHistory,
    bool? isSubmittingAction,
    int? activeRideId,
    String? activeAction,
    String? availableErrorMessage,
    String? historyErrorMessage,
    bool clearActiveRide = false,
    bool clearAvailableErrorMessage = false,
    bool clearHistoryErrorMessage = false,
  }) {
    return RideDriverState(
      availableRides: availableRides ?? this.availableRides,
      rides: rides ?? this.rides,
      isLoadingAvailable: isLoadingAvailable ?? this.isLoadingAvailable,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSubmittingAction: isSubmittingAction ?? this.isSubmittingAction,
      activeRideId: clearActiveRide ? null : activeRideId ?? this.activeRideId,
      activeAction: clearActiveRide ? null : activeAction ?? this.activeAction,
      availableErrorMessage: clearAvailableErrorMessage
          ? null
          : availableErrorMessage ?? this.availableErrorMessage,
      historyErrorMessage: clearHistoryErrorMessage
          ? null
          : historyErrorMessage ?? this.historyErrorMessage,
    );
  }
}

class RideDriverController extends StateNotifier<RideDriverState> {
  RideDriverController({required DriverRidesRepository repository})
      : _repository = repository,
        super(const RideDriverState.initial());

  final DriverRidesRepository _repository;

  Future<void> fetchAvailableRides() async {
    if (state.isLoadingAvailable) {
      return;
    }

    state = state.copyWith(
      isLoadingAvailable: true,
      clearAvailableErrorMessage: true,
    );

    try {
      final rides = await _repository.fetchAvailableRides();
      state = state.copyWith(
        availableRides: rides,
        isLoadingAvailable: false,
        clearAvailableErrorMessage: true,
      );
    } on DriverRideFailure catch (error) {
      state = state.copyWith(
        isLoadingAvailable: false,
        availableErrorMessage: error.message,
      );
    }
  }

  Future<void> loadRides() async {
    if (state.isLoadingHistory) {
      return;
    }

    state = state.copyWith(
      isLoadingHistory: true,
      clearHistoryErrorMessage: true,
    );

    try {
      final rides = await _repository.fetchMyRides();
      state = state.copyWith(
        rides: rides,
        isLoadingHistory: false,
        clearHistoryErrorMessage: true,
      );
    } on DriverRideFailure catch (error) {
      state = state.copyWith(
        isLoadingHistory: false,
        historyErrorMessage: error.message,
      );
    }
  }

  Future<void> refreshRealtimeSnapshot({
    bool includeAvailableRides = true,
    bool includeHistory = true,
  }) async {
    final tasks = <Future<void>>[];

    if (includeAvailableRides) {
      tasks.add(fetchAvailableRides());
    }

    if (includeHistory) {
      tasks.add(loadRides());
    }

    if (tasks.isEmpty) {
      return;
    }

    await Future.wait(tasks);
  }

  Future<void> resumeFromLifecycle({
    bool includeAvailableRides = true,
    bool includeHistory = true,
  }) async {
    final tasks = <Future<void>>[];

    if (includeAvailableRides) {
      tasks.add(_refreshAvailableRidesSilently());
    }

    if (includeHistory) {
      tasks.add(_refreshHistorySilently());
    }

    if (tasks.isEmpty) {
      return;
    }

    await Future.wait(tasks);
  }

  Future<String?> rejectRide(int rideId, {String? reason}) async {
    state = state.copyWith(
      isSubmittingAction: true,
      activeRideId: rideId,
      activeAction: 'reject',
      clearAvailableErrorMessage: true,
    );

    try {
      await _repository.rejectRide(rideId, reason: reason);
      state = state.copyWith(
        availableRides: _removeAvailableRide(rideId),
        isSubmittingAction: false,
        clearActiveRide: true,
        clearAvailableErrorMessage: true,
      );
      return null;
    } on DriverRideFailure catch (error) {
      state = state.copyWith(
        isSubmittingAction: false,
        clearActiveRide: true,
        availableErrorMessage: error.message,
      );
      return error.message;
    }
  }

  List<DriverRide> _removeAvailableRide(int rideId) {
    return state.availableRides.where((ride) => ride.id != rideId).toList();
  }

  Future<void> _refreshAvailableRidesSilently() async {
    try {
      final rides = await _repository.fetchAvailableRides();
      state = state.copyWith(
        availableRides: rides,
        clearAvailableErrorMessage: true,
      );
    } on DriverRideFailure catch (error) {
      if (state.availableRides.isEmpty) {
        state = state.copyWith(availableErrorMessage: error.message);
      }
    }
  }

  Future<void> _refreshHistorySilently() async {
    try {
      final rides = await _repository.fetchMyRides();
      state = state.copyWith(
        rides: rides,
        clearHistoryErrorMessage: true,
      );
    } on DriverRideFailure catch (error) {
      if (state.rides.isEmpty) {
        state = state.copyWith(historyErrorMessage: error.message);
      }
    }
  }
}

final rideDriverProvider =
    StateNotifierProvider<RideDriverController, RideDriverState>((ref) {
  return RideDriverController(
    repository: ref.watch(driverRidesRepositoryProvider),
  );
});

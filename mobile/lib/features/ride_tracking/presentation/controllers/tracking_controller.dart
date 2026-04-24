import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/lifecycle/app_lifecycle_recovery_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../data/datasources/tracking_remote_datasource.dart';
import '../../data/datasources/tracking_websocket_datasource.dart';
import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';
import 'tracking_controller_support.dart';

part 'tracking_controller_realtime.dart';
part 'tracking_controller_snapshot.dart';

class TrackingControllerScope {
  const TrackingControllerScope({
    required this.mode,
    this.rideId,
  });

  final TrackingMode mode;
  final int? rideId;

  @override
  bool operator ==(Object other) {
    return other is TrackingControllerScope &&
        other.mode == mode &&
        other.rideId == rideId;
  }

  @override
  int get hashCode => Object.hash(mode, rideId);
}

class TrackingController extends StateNotifier<TrackingState> {
  TrackingController({
    required this.ref,
    required this.mode,
    this.preferredRideId,
    required TrackingRemoteDatasource remoteDatasource,
    required TrackingWebSocketDatasource websocketDatasource,
    required LocationService locationService,
  })  : _remoteDatasource = remoteDatasource,
        _websocketDatasource = websocketDatasource,
        _locationService = locationService,
        super(TrackingState.initial(mode));

  final Ref ref;
  final TrackingMode mode;
  final int? preferredRideId;
  final TrackingRemoteDatasource _remoteDatasource;
  final TrackingWebSocketDatasource _websocketDatasource;
  final LocationService _locationService;

  StreamSubscription<TrackingSocketEvent>? _eventSubscription;
  StreamSubscription<TrackingConnectionState>? _connectionSubscription;
  StreamSubscription<LocationResult<Position>>? _locationSubscription;
  DateTime? _lastDriverPingAt;
  bool _started = false;
  void Function()? _unregisterLifecycleResume;

  TrackingState get _currentState => state;
  set _currentState(TrackingState value) => state = value;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    _registerLifecycleResume();
    state = state.copyWith(isLoading: true, clearError: true);
    await _refreshSnapshot(this);
    await _bindRealtime(this);
    _startLocationTracking(this);
    state = state.copyWith(isLoading: false);
  }

  Future<void> stop() async {
    _started = false;
    _unregisterLifecycleResume?.call();
    _unregisterLifecycleResume = null;
    await _eventSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _locationSubscription?.cancel();
    _eventSubscription = null;
    _connectionSubscription = null;
    _locationSubscription = null;
    await _websocketDatasource.disconnect();
    state = TrackingState.initial(mode);
  }

  Future<void> refreshPosition() async {
    final result = await _locationService.getCurrentPosition();
    if (result case LocationSuccess<Position>(value: final position)) {
      _applyCurrentPosition(this, position);
      return;
    }
    if (result case LocationError<Position>(failure: final failure)) {
      state = state.copyWith(errorMessage: failure.message);
    }
  }

  Future<void> refresh() => _refreshSnapshot(this);

  Future<void> resumeFromLifecycle() async {
    if (!_started) {
      return;
    }

    await _websocketDatasource.resumeFromLifecycle();
    _startLocationTracking(this);
    await _refreshSnapshot(this);
  }

  Future<void> cancelRide() async {
    await _runRideAction(
      this,
      action: (rideId) => _remoteDatasource.cancelRide(rideId),
      successMessage: 'Course annulee.',
    );
  }

  Future<void> markArrived() async {
    await _runRideAction(
      this,
      action: (rideId) => _remoteDatasource.markArrived(rideId),
      successMessage: 'Votre arrivee a ete signalee.',
    );
  }

  Future<void> startRide() async {
    await _runRideAction(
      this,
      action: (rideId) => _remoteDatasource.startRide(rideId),
      successMessage: 'Course demarree.',
    );
  }

  Future<void> completeRide() async {
    await _runRideAction(
      this,
      action: (rideId) => _remoteDatasource.completeRide(rideId),
      successMessage: 'Course terminee.',
    );
  }

  Future<void> rateDriver({
    required double rating,
    String? comment,
  }) async {
    final ride = state.ride;
    if (ride == null) {
      return;
    }

    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final payload = await _remoteDatasource.rateDriver(
        rideId: ride.id,
        rating: rating,
        comment: comment,
      );
      state = state.copyWith(
        isActionLoading: false,
        ride: RideTrackingModel.fromJson(payload),
        toastMessage: 'Merci pour votre note.',
      );
    } on TrackingRemoteFailure catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: error.message,
      );
    }
  }

  Future<void> reportRide({
    required String reason,
    String? description,
  }) async {
    final ride = state.ride;
    if (ride == null) {
      return;
    }

    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      await _remoteDatasource.reportRide(
        rideId: ride.id,
        reason: reason,
        description: description,
      );
      state = state.copyWith(
        isActionLoading: false,
        toastMessage: 'Signalement envoye.',
      );
    } on TrackingRemoteFailure catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: error.message,
      );
    }
  }

  void acknowledgePassengerReady() {
    state = state.copyWith(
      toastMessage:
          'Parfait. Votre chauffeur vous attend juste devant le point de depart.',
    );
  }

  Future<void> openAppSettings() => _locationService.openAppSettings();
  Future<void> openLocationSettings() =>
      _locationService.openLocationSettings();

  void consumeToast() {
    state = state.copyWith(clearToast: true);
  }

  void _registerLifecycleResume() {
    _unregisterLifecycleResume?.call();
    _unregisterLifecycleResume =
        ref.read(appLifecycleRecoveryServiceProvider).registerResumeHandler(
              'tracking-${mode.name}-${preferredRideId ?? 'active'}',
              resumeFromLifecycle,
            );
  }
}

final trackingControllerProvider = StateNotifierProvider.autoDispose
    .family<TrackingController, TrackingState, TrackingControllerScope>(
  (ref, scope) {
    final controller = TrackingController(
      ref: ref,
      mode: scope.mode,
      preferredRideId: scope.rideId,
      remoteDatasource: ref.watch(trackingRemoteDatasourceProvider),
      websocketDatasource: ref.watch(
        trackingWebsocketDatasourceProvider(scope.mode),
      ),
      locationService: ref.watch(locationServiceProvider),
    );
    ref.onDispose(() {
      controller.stop();
    });
    return controller;
  },
);

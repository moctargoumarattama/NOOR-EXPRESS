import '../../data/models/ride_tracking_model.dart';

enum TrackingMode {
  client,
  driver,
}

enum TrackingConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class TrackingState {
  const TrackingState({
    required this.mode,
    required this.connectionState,
    required this.isLoading,
    required this.isActionLoading,
    this.ride,
    this.counterpart,
    this.currentPosition,
    this.driverPosition,
    this.driverHeadingDegrees,
    this.etaMinutes,
    this.distanceRemainingKm,
    this.isEtaReliable = false,
    this.routePoints = const [],
    this.errorMessage,
    this.toastMessage,
  });

  const TrackingState.initial(TrackingMode mode)
      : this(
          mode: mode,
          connectionState: TrackingConnectionState.disconnected,
          isLoading: false,
          isActionLoading: false,
        );

  final TrackingMode mode;
  final TrackingConnectionState connectionState;
  final bool isLoading;
  final bool isActionLoading;
  final RideTrackingModel? ride;
  final TrackingCounterpartModel? counterpart;
  final TrackingCoordinates? currentPosition;
  final TrackingCoordinates? driverPosition;
  final double? driverHeadingDegrees;
  final int? etaMinutes;
  final double? distanceRemainingKm;
  final bool isEtaReliable;
  final List<TrackingCoordinates> routePoints;
  final String? errorMessage;
  final String? toastMessage;

  bool get hasRide => ride != null;

  TrackingState copyWith({
    TrackingConnectionState? connectionState,
    bool? isLoading,
    bool? isActionLoading,
    RideTrackingModel? ride,
    TrackingCounterpartModel? counterpart,
    TrackingCoordinates? currentPosition,
    TrackingCoordinates? driverPosition,
    double? driverHeadingDegrees,
    int? etaMinutes,
    double? distanceRemainingKm,
    bool? isEtaReliable,
    List<TrackingCoordinates>? routePoints,
    String? errorMessage,
    String? toastMessage,
    bool clearRide = false,
    bool clearCounterpart = false,
    bool clearCurrentPosition = false,
    bool clearDriverPosition = false,
    bool clearHeading = false,
    bool clearEta = false,
    bool clearDistanceRemaining = false,
    bool clearRoute = false,
    bool clearError = false,
    bool clearToast = false,
  }) {
    return TrackingState(
      mode: mode,
      connectionState: connectionState ?? this.connectionState,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      ride: clearRide ? null : ride ?? this.ride,
      counterpart: clearCounterpart ? null : counterpart ?? this.counterpart,
      currentPosition: clearCurrentPosition
          ? null
          : currentPosition ?? this.currentPosition,
      driverPosition:
          clearDriverPosition ? null : driverPosition ?? this.driverPosition,
      driverHeadingDegrees:
          clearHeading ? null : driverHeadingDegrees ?? this.driverHeadingDegrees,
      etaMinutes: clearEta ? null : etaMinutes ?? this.etaMinutes,
      distanceRemainingKm: clearDistanceRemaining
          ? null
          : distanceRemainingKm ?? this.distanceRemainingKm,
      isEtaReliable: isEtaReliable ?? this.isEtaReliable,
      routePoints: clearRoute ? const [] : routePoints ?? this.routePoints,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      toastMessage: clearToast ? null : toastMessage ?? this.toastMessage,
    );
  }
}

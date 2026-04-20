import '../../data/models/ride_offer_model.dart';

enum NegotiationMode {
  client,
  driver,
}

enum NegotiationConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class NegotiationState {
  const NegotiationState({
    required this.mode,
    required this.rideId,
    required this.connectionState,
    required this.isLoading,
    required this.isSubmitting,
    required this.hasSubmittedOffer,
    this.ride,
    this.offers = const [],
    this.submittedPrice,
    this.errorMessage,
    this.toastMessage,
    this.navigateToTrackingRideId,
    this.shouldCloseToHome = false,
  });

  const NegotiationState.initial({
    required NegotiationMode mode,
    required int rideId,
  }) : this(
          mode: mode,
          rideId: rideId,
          connectionState: NegotiationConnectionState.disconnected,
          isLoading: false,
          isSubmitting: false,
          hasSubmittedOffer: false,
        );

  final NegotiationMode mode;
  final int rideId;
  final NegotiationConnectionState connectionState;
  final bool isLoading;
  final bool isSubmitting;
  final bool hasSubmittedOffer;
  final NegotiationRideModel? ride;
  final List<RideOfferModel> offers;
  final double? submittedPrice;
  final String? errorMessage;
  final String? toastMessage;
  final int? navigateToTrackingRideId;
  final bool shouldCloseToHome;

  NegotiationState copyWith({
    NegotiationConnectionState? connectionState,
    bool? isLoading,
    bool? isSubmitting,
    bool? hasSubmittedOffer,
    NegotiationRideModel? ride,
    List<RideOfferModel>? offers,
    double? submittedPrice,
    String? errorMessage,
    String? toastMessage,
    int? navigateToTrackingRideId,
    bool? shouldCloseToHome,
    bool clearRide = false,
    bool clearError = false,
    bool clearToast = false,
    bool clearNavigation = false,
  }) {
    return NegotiationState(
      mode: mode,
      rideId: rideId,
      connectionState: connectionState ?? this.connectionState,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasSubmittedOffer: hasSubmittedOffer ?? this.hasSubmittedOffer,
      ride: clearRide ? null : ride ?? this.ride,
      offers: offers ?? this.offers,
      submittedPrice: submittedPrice ?? this.submittedPrice,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      toastMessage: clearToast ? null : toastMessage ?? this.toastMessage,
      navigateToTrackingRideId: clearNavigation
          ? null
          : navigateToTrackingRideId ?? this.navigateToTrackingRideId,
      shouldCloseToHome: shouldCloseToHome ?? this.shouldCloseToHome,
    );
  }
}

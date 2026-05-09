import 'package:flutter/material.dart';

import '../../../../../core/location/location_quality.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../data/models/client_ride.dart';
import '../../../../address_search/domain/entities/address_result.dart';
import '../../../../map/models/route_result.dart';
import '../../../../negotiation/data/models/ride_offer_model.dart';
import '../../../../negotiation/presentation/widgets/offer_card.dart';
import 'ride_bottom_sheet_shell.dart';
import 'route_summary_card.dart';
import 'price_selector.dart';

part 'search_bottom_sheet_sections.dart';

typedef AddDropoffToFavorites = Future<void> Function(AddressResult dropoff);
typedef SelectRecentAddress = void Function(AddressResult address);

class SearchBottomSheet extends StatelessWidget {
  static const double _loadingOffersInitialSize = 0.56;
  static const double _loadingOffersMaxSize = 0.76;
  static const double _offerReceivedInitialSize = 0.78;
  static const double _offerReceivedMaxSize = 0.92;
  static const double _searchingInitialSize = 0.66;
  static const double _searchingMaxSize = 0.84;
  static const double _idleInitialSize = 0.30;
  static const double _idleMaxSize = 0.62;
  static const double _routePreviewInitialSize = 0.88;
  static const double _routePreviewMaxSize = 0.95;

  const SearchBottomSheet({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.recentDepartureLabels,
    this.recentAddresses = const [],
    required this.priceController,
    required this.isCreating,
    required this.isEstimatingPrice,
    required this.pickupLocationQuality,
    required this.canSubmitRideRequest,
    required this.activeRide,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    required this.onOpenActiveRide,
    this.onRecentTap,
    this.estimate,
    this.estimateError,
    this.submitDisabledReason,
    this.route,
    this.routeError,
    this.activeRideRoute,
    this.nearbyDriversCount,
    this.onCancelActiveRide,
    this.offers = const [],
    this.isLoadingOffers = false,
    this.acceptingOfferId,
    this.rejectingOfferId,
    this.onAcceptOffer,
    this.onRejectOffer,
    this.onViewAllOffers,
    this.onAddToFavorites,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final List<String> recentDepartureLabels;
  final List<AddressResult> recentAddresses;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final LocationQuality pickupLocationQuality;
  final bool canSubmitRideRequest;
  final String? submitDisabledReason;
  final ClientRide? activeRide;
  final RouteResult? route;
  final RouteResult? activeRideRoute;
  final int? nearbyDriversCount;
  final List<RideOfferModel> offers;
  final bool isLoadingOffers;
  final int? acceptingOfferId;
  final int? rejectingOfferId;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;
  final VoidCallback onOpenActiveRide;
  final SelectRecentAddress? onRecentTap;
  final VoidCallback? onCancelActiveRide;
  final ValueChanged<RideOfferModel>? onAcceptOffer;
  final ValueChanged<RideOfferModel>? onRejectOffer;
  final VoidCallback? onViewAllOffers;
  final AddDropoffToFavorites? onAddToFavorites;
  final PriceEstimate? estimate;
  final String? estimateError;
  final String? routeError;

  @override
  Widget build(BuildContext context) {
    final initialSize = _isLoadingOfferList
        ? _loadingOffersInitialSize
        : _hasOfferReceived
            ? _offerReceivedInitialSize
            : _isSearching
                ? _searchingInitialSize
                : dropoff == null
                    ? _idleInitialSize
                    : _routePreviewInitialSize;
    final maxSize = _isLoadingOfferList
        ? _loadingOffersMaxSize
        : _hasOfferReceived
            ? _offerReceivedMaxSize
            : _isSearching
                ? _searchingMaxSize
                : dropoff == null
                    ? _idleMaxSize
                    : _routePreviewMaxSize;

    return RideBottomSheetShell(
      initialChildSize: initialSize,
      minChildSize: 0.22,
      maxChildSize: maxSize,
      snapSizes: [initialSize, maxSize],
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isLoadingOfferList
            ? _OffersLoadingPanel(
                key: ValueKey('offers-loading-${activeRide!.id}'),
                ride: activeRide!,
                route: activeRideRoute,
              )
            : _hasOfferReceived
                ? _OfferReceivedPanel(
                    key: ValueKey('offer-received-${activeRide!.id}'),
                    ride: activeRide!,
                    route: activeRideRoute,
                    offers: offers,
                    isRefreshingOffers: isLoadingOffers,
                    acceptingOfferId: acceptingOfferId,
                    rejectingOfferId: rejectingOfferId,
                    onAcceptOffer: onAcceptOffer,
                    onRejectOffer: onRejectOffer,
                    onViewAllOffers: onViewAllOffers,
                  )
                : _isSearching
                    ? _SearchingRidePanel(
                        key: ValueKey('searching-${activeRide!.id}'),
                        ride: activeRide!,
                        route: activeRideRoute,
                        nearbyDriversCount: nearbyDriversCount,
                        onCancel: onCancelActiveRide,
                      )
                    : _BookingPanel(
                        key: ValueKey(
                            dropoff == null ? 'idle' : 'route-preview'),
                        pickup: pickup,
                        dropoff: dropoff,
                        route: route,
                        routeError: routeError,
                        recentDepartureLabels: recentDepartureLabels,
                        recentAddresses: recentAddresses,
                        priceController: priceController,
                        isCreating: isCreating,
                        isEstimatingPrice: isEstimatingPrice,
                        pickupLocationQuality: pickupLocationQuality,
                        canSubmitRideRequest: canSubmitRideRequest,
                        submitDisabledReason: submitDisabledReason,
                        estimate: estimate,
                        onPickupTap: onPickupTap,
                        onDropoffTap: onDropoffTap,
                        onRecentTap: onRecentTap,
                        onClearPickup: onClearPickup,
                        onClearDropoff: onClearDropoff,
                        onSubmit: onSubmit,
                        onAddToFavorites: onAddToFavorites,
                      ),
      ),
    );
  }

  bool get _isSearching {
    final status = activeRide?.status;
    return status == 'pending' || status == 'offered';
  }

  bool get _hasOfferReceived {
    return activeRide?.status == 'offered' && offers.isNotEmpty;
  }

  bool get _isLoadingOfferList {
    return activeRide?.status == 'offered' && isLoadingOffers && offers.isEmpty;
  }
}

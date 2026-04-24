import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../data/models/client_ride.dart';
import '../../../../address_search/domain/entities/address_result.dart';
import '../../../../map/models/route_result.dart';
import 'address_input_card.dart';
import 'ride_bottom_sheet_shell.dart';
import 'route_summary_card.dart';
import 'price_selector.dart';

part 'search_bottom_sheet_sections.dart';

class SearchBottomSheet extends StatelessWidget {
  const SearchBottomSheet({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.recentDepartureLabels,
    required this.priceController,
    required this.isCreating,
    required this.isEstimatingPrice,
    required this.activeRide,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onClearPickup,
    required this.onClearDropoff,
    required this.onSubmit,
    required this.onOpenActiveRide,
    this.estimate,
    this.estimateError,
    this.route,
    this.routeError,
    this.activeRideRoute,
    this.nearbyDriversCount,
    this.onCancelActiveRide,
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final List<String> recentDepartureLabels;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final ClientRide? activeRide;
  final RouteResult? route;
  final RouteResult? activeRideRoute;
  final int? nearbyDriversCount;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;
  final VoidCallback onOpenActiveRide;
  final VoidCallback? onCancelActiveRide;
  final PriceEstimate? estimate;
  final String? estimateError;
  final String? routeError;

  @override
  Widget build(BuildContext context) {
    final initialSize = _isSearching
        ? 0.66
        : dropoff == null
            ? 0.30
            : 0.50;
    final maxSize = _isSearching
        ? 0.84
        : dropoff == null
            ? 0.62
            : 0.72;

    return RideBottomSheetShell(
      initialChildSize: initialSize,
      minChildSize: 0.22,
      maxChildSize: maxSize,
      snapSizes: [initialSize, maxSize],
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isSearching
            ? _SearchingRidePanel(
                key: ValueKey('searching-${activeRide!.id}'),
                ride: activeRide!,
                route: activeRideRoute,
                nearbyDriversCount: nearbyDriversCount,
                onOpen: onOpenActiveRide,
                onCancel: onCancelActiveRide,
              )
            : _BookingPanel(
                key: ValueKey(dropoff == null ? 'idle' : 'route-preview'),
                pickup: pickup,
                dropoff: dropoff,
                route: route,
                routeError: routeError,
                recentDepartureLabels: recentDepartureLabels,
                priceController: priceController,
                isCreating: isCreating,
                isEstimatingPrice: isEstimatingPrice,
                estimate: estimate,
                estimateError: estimateError,
                onPickupTap: onPickupTap,
                onDropoffTap: onDropoffTap,
                onClearPickup: onClearPickup,
                onClearDropoff: onClearDropoff,
                onSubmit: onSubmit,
              ),
      ),
    );
  }

  bool get _isSearching {
    final status = activeRide?.status;
    return status == 'pending' || status == 'offered';
  }
}

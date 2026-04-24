import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../../../../shared/widgets/status_badge.dart';
import '../../data/models/client_ride.dart';
import '../../../../address_search/domain/entities/address_result.dart';
import 'address_input_card.dart';

part 'search_bottom_sheet_sections.dart';

class SearchBottomSheet extends StatelessWidget {
  const SearchBottomSheet({
    super.key,
    required this.pickup,
    required this.dropoff,
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
  });

  final AddressResult? pickup;
  final AddressResult? dropoff;
  final TextEditingController priceController;
  final bool isCreating;
  final bool isEstimatingPrice;
  final ClientRide? activeRide;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDropoff;
  final VoidCallback onSubmit;
  final VoidCallback onOpenActiveRide;
  final PriceEstimate? estimate;
  final String? estimateError;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.30,
        minChildSize: 0.22,
        maxChildSize: 0.62,
        snap: true,
        snapSizes: const [0.30, 0.62],
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isSearching
                      ? _SearchingRidePanel(
                          key: ValueKey('searching-${activeRide!.id}'),
                          ride: activeRide!,
                          onOpen: onOpenActiveRide,
                        )
                      : _BookingPanel(
                          key: const ValueKey('booking'),
                          pickup: pickup,
                          dropoff: dropoff,
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
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _isSearching => activeRide != null;
}

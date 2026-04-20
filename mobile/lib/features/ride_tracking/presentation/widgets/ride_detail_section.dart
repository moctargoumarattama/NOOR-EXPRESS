import 'package:flutter/material.dart';

import '../../data/models/ride_tracking_model.dart';
import 'driver_info_card.dart';

class RideDetailSection extends StatelessWidget {
  const RideDetailSection({
    super.key,
    required this.ride,
    required this.roleLabel,
    this.counterpart,
  });

  final RideTrackingModel ride;
  final TrackingCounterpartModel? counterpart;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (counterpart != null)
          DriverInfoCard(
            counterpart: counterpart!,
            roleLabel: roleLabel,
            priceLabel: '${ride.displayedPrice.toStringAsFixed(0)} FCFA',
          ),
        if (counterpart != null) const SizedBox(height: 18),
        RideDetailRow(label: 'Depart', value: ride.pickupLocation),
        const SizedBox(height: 10),
        RideDetailRow(label: 'Destination', value: ride.dropoffLocation),
      ],
    );
  }
}

class RideDetailRow extends StatelessWidget {
  const RideDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7A8598),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

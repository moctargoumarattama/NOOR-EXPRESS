import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/client_profile_model.dart';

class ProfileRideHistory extends StatelessWidget {
  const ProfileRideHistory({
    super.key,
    required this.rides,
    required this.onOpenRide,
  });

  final List<ClientProfileRideModel> rides;
  final ValueChanged<ClientProfileRideModel> onOpenRide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des courses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        if (rides.isEmpty)
          const _EmptyHistory()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rides.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return ListTile(
                key: ValueKey('profile-ride-${ride.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.emerald,
                ),
                title:
                    Text('${ride.pickupLocation} -> ${ride.dropoffLocation}'),
                subtitle: Text(
                  '${ride.displayPrice.round()} FCFA - ${ride.status}',
                ),
                onTap: () => onOpenRide(ride),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text('Aucune course recente pour le moment.'),
    );
  }
}

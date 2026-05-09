import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/address_result.dart';
import 'address_result_tile.dart';

class RecentAddressesList extends StatelessWidget {
  const RecentAddressesList({
    super.key,
    required this.recents,
    required this.onSelected,
    this.maxItems = 3,
  });

  final List<AddressResult> recents;
  final ValueChanged<AddressResult> onSelected;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(label: 'Recents'),
        ...recents.take(maxItems).map(
              (result) => AddressResultTile(
                key: ValueKey('recent-${result.name}-${result.latitude}'),
                result: result,
                icon: Icons.history_rounded,
                onTap: () => onSelected(result),
              ),
            ),
      ],
    );
  }
}

class FavoriteAddressesList extends StatelessWidget {
  const FavoriteAddressesList({
    super.key,
    required this.favorites,
    required this.onSelected,
    this.maxItems = 2,
  });

  final List<AddressResult> favorites;
  final ValueChanged<AddressResult> onSelected;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(label: 'Favoris'),
        ...favorites.take(maxItems).map(
              (result) => AddressResultTile(
                key: ValueKey('favorite-${result.name}-${result.latitude}'),
                result: result,
                icon: _iconForLabel(result.name),
                onTap: () => onSelected(result),
              ),
            ),
      ],
    );
  }

  IconData _iconForLabel(String label) {
    final normalizedLabel = label.trim().toLowerCase();
    if (normalizedLabel == 'maison') {
      return Icons.home_rounded;
    }
    if (normalizedLabel == 'bureau') {
      return Icons.business_rounded;
    }
    return Icons.bookmark_rounded;
  }
}

class AddressSectionTitle extends StatelessWidget {
  const AddressSectionTitle({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => _SectionTitle(label: label);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.nigerOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

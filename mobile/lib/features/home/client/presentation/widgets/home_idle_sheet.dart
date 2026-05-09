import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../address_search/domain/entities/address_result.dart';

class HomeIdleSheet extends StatelessWidget {
  static const int _maxFavoriteShortcuts = 3;
  static const int _maxRecentShortcuts = 2;

  const HomeIdleSheet({
    super.key,
    required this.favorites,
    required this.recents,
    required this.onSearchTap,
    required this.onFavoriteTap,
    required this.onRecentTap,
  });

  final List<AddressResult> favorites;
  final List<AddressResult> recents;
  final VoidCallback onSearchTap;
  final ValueChanged<AddressResult> onFavoriteTap;
  final ValueChanged<AddressResult> onRecentTap;

  @override
  Widget build(BuildContext context) {
    final visibleFavorites = favorites
        .take(_maxFavoriteShortcuts)
        .toList(growable: false);
    final visibleRecents = _visibleRecents(visibleFavorites);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 10),
            const _RideBadge(),
            const SizedBox(height: 10),
            _TitleBlock(theme: Theme.of(context)),
            const SizedBox(height: 6),
            _SearchLauncher(
              onTap: onSearchTap,
              textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.stone,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (visibleFavorites.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ShortcutSection(
                title: 'Favoris',
                icon: Icons.bookmark_rounded,
                addresses: visibleFavorites,
                onTap: onFavoriteTap,
              ),
            ],
            if (visibleRecents.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ShortcutSection(
                title: 'Recents',
                icon: Icons.history_rounded,
                addresses: visibleRecents,
                onTap: onRecentTap,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<AddressResult> _visibleRecents(List<AddressResult> visibleFavorites) {
    final favoriteKeys = visibleFavorites.map(_addressKey).toSet();
    return recents
        .where((address) => !favoriteKeys.contains(_addressKey(address)))
        .take(_maxRecentShortcuts)
        .toList(growable: false);
  }

  String _addressKey(AddressResult address) {
    return '${address.name.toLowerCase()}|'
        '${address.displayName.toLowerCase()}|'
        '${address.latitude}|${address.longitude}';
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _RideBadge extends StatelessWidget {
  const _RideBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Course',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.emerald,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Votre destination',
      style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({
    required this.onTap,
    required this.textStyle,
  });

  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.emerald),
            const SizedBox(width: 10),
            Text('Ou allez-vous ?', style: textStyle),
          ],
        ),
      ),
    );
  }
}

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({
    required this.title,
    required this.icon,
    required this.addresses,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final List<AddressResult> addresses;
  final ValueChanged<AddressResult> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < addresses.length; index++) ...[
                _ShortcutPill(
                  label: addresses[index].name,
                  icon: icon,
                  onTap: () => onTap(addresses[index]),
                ),
                if (index != addresses.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.pearl,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppColors.emerald,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

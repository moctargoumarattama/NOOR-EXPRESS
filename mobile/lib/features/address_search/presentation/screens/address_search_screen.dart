import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/address_result.dart';
import '../controllers/address_search_controller.dart';
import '../widgets/address_result_tile.dart';
import '../widgets/address_search_bar.dart';
import '../widgets/recent_addresses_list.dart';

enum AddressSearchMode { pickup, dropoff }

class AddressSearchScreen extends ConsumerStatefulWidget {
  const AddressSearchScreen({
    super.key,
    required this.mode,
  });

  final AddressSearchMode mode;

  @override
  ConsumerState<AddressSearchScreen> createState() =>
      _AddressSearchScreenState();
}

class _AddressSearchScreenState extends ConsumerState<AddressSearchScreen> {
  static const _maxDefaultVisibleResults = 6;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(addressSearchControllerProvider.notifier)
        ..loadFavorites()
        ..loadRecents();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _select(AddressResult result) async {
    if (_isSelecting) {
      return;
    }
    setState(() => _isSelecting = true);

    // The home flow must not wait on local/web storage to keep navigation fast.
    unawaited(_saveRecentSilently(result));

    if (!mounted) {
      return;
    }
    try {
      context.pop(result);
    } catch (error) {
      debugPrint('[AddressSearch] pop failed: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isSelecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selection impossible. Reessayez.'),
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final result = await ref
        .read(addressSearchControllerProvider.notifier)
        .currentLocation();
    if (result != null && mounted) {
      context.pop(result);
    }
  }

  Future<void> _saveRecentSilently(AddressResult result) async {
    try {
      await ref
          .read(addressSearchControllerProvider.notifier)
          .saveRecent(result);
    } catch (error) {
      debugPrint('[AddressSearch] save recent skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressSearchControllerProvider);
    final theme = Theme.of(context);
    final hasQuery = state.query.trim().isNotEmpty;
    final visibleResults = hasQuery
        ? state.results
        : state.results.take(_maxDefaultVisibleResults).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchHeader(
                    mode: widget.mode,
                    onClose: () => context.pop(),
                  ),
                  const SizedBox(height: 16),
                  AddressSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !_isSelecting,
                    hintText: widget.mode == AddressSearchMode.pickup
                        ? 'Rechercher votre point de depart'
                        : 'Rechercher votre destination',
                    onChanged: ref
                        .read(addressSearchControllerProvider.notifier)
                        .search,
                  ),
                  const SizedBox(height: 12),
                  _CurrentLocationButton(
                    isBusy: state.isResolvingCurrentLocation || _isSelecting,
                    onTap: _useCurrentLocation,
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.pearl,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
                    if (!hasQuery)
                      FavoriteAddressesList(
                        favorites: state.favorites,
                        maxItems: 2,
                        onSelected: _select,
                      ),
                    if (!hasQuery)
                      RecentAddressesList(
                        recents: state.recents,
                        maxItems: 3,
                        onSelected: _select,
                      ),
                    AddressSectionTitle(
                      label: hasQuery ? 'Resultats' : 'Zones Niamey',
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: state.isLoading
                          ? const _AddressLoadingList()
                          : visibleResults.isEmpty
                              ? _EmptyResultState(hasQuery: hasQuery)
                              : Column(
                                  key: ValueKey(
                                    'results-${state.query}-${visibleResults.length}',
                                  ),
                                  children: [
                                    for (var index = 0;
                                        index < visibleResults.length;
                                        index++)
                                      _SlideInResult(
                                        index: index,
                                        child: AddressResultTile(
                                          key: ValueKey(
                                            '${visibleResults[index].name}-$index',
                                          ),
                                          result: visibleResults[index],
                                          trailing: _isSelecting
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : null,
                                          onTap: () => _select(
                                            visibleResults[index],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.mode,
    required this.onClose,
  });

  final AddressSearchMode mode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = mode == AddressSearchMode.pickup
        ? 'Point de prise en charge'
        : 'Ou allez-vous ?';
    final subtitle = mode == AddressSearchMode.pickup
        ? 'Choisissez un depart clair pour votre chauffeur.'
        : 'Choisissez votre destination sans stress.';

    return Row(
      children: [
        Material(
          color: AppColors.pearl,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onClose,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({
    required this.isBusy,
    required this.onTap,
  });

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pearl,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isBusy
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.nigerGreenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 19,
                  color: AppColors.nigerGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ma position actuelle',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Utiliser le GPS de ce telephone',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isBusy
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        key: ValueKey('chevron'),
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideInResult extends StatelessWidget {
  const _SlideInResult({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 170 + (index * 25).clamp(0, 150)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _AddressLoadingList extends StatelessWidget {
  const _AddressLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('address-loading'),
      children: List.generate(4, (index) => const _ShimmerRow()),
    );
  }
}

class _ShimmerRow extends StatefulWidget {
  const _ShimmerRow();

  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alpha = 0.06 + (_controller.value * 0.08);
        return Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.nigerOrange.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(18),
          ),
        );
      },
    );
  }
}

class _EmptyResultState extends StatelessWidget {
  const _EmptyResultState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('address-empty'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_searching_rounded,
            size: 30,
            color: AppColors.nigerOrange,
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery ? 'Aucune adresse trouvee.' : 'Aucune zone disponible.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Essayez un autre mot-cle ou utilisez votre position actuelle.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

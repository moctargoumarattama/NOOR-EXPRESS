import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    // La selection doit revenir immediatement a l'accueil; les recents ne
    // doivent jamais bloquer le flux si le stockage web/local a un souci.
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.mode == AddressSearchMode.pickup
                        ? 'Votre position'
                        : 'Ou allez-vous ?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AddressSearchBar(
                controller: _controller,
                focusNode: _focusNode,
                onChanged:
                    ref.read(addressSearchControllerProvider.notifier).search,
              ),
              const SizedBox(height: 14),
              AddressResultTile(
                result: const _CurrentLocationResult(),
                icon: Icons.my_location_rounded,
                trailing: state.isResolvingCurrentLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: state.isResolvingCurrentLocation || _isSelecting
                    ? () {}
                    : _useCurrentLocation,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (state.query.trim().isEmpty)
                      FavoriteAddressesList(
                        favorites: state.favorites,
                        onSelected: _select,
                      ),
                    if (state.query.trim().isEmpty)
                      RecentAddressesList(
                        recents: state.recents,
                        onSelected: _select,
                      ),
                    AddressSectionTitle(
                      label: state.query.trim().isEmpty
                          ? 'Zones Niamey'
                          : 'Resultats',
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: state.isLoading
                          ? const _AddressLoadingList()
                          : Column(
                              key: ValueKey(
                                'results-${state.query}-${state.results.length}',
                              ),
                              children: [
                                for (var index = 0;
                                    index < state.results.length;
                                    index++)
                                  _SlideInResult(
                                    index: index,
                                    child: AddressResultTile(
                                      key: ValueKey(
                                        '${state.results[index].name}-$index',
                                      ),
                                      result: state.results[index],
                                      trailing: _isSelecting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : null,
                                      onTap: () =>
                                          _select(state.results[index]),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationResult extends AddressResult {
  const _CurrentLocationResult()
      : super(
          name: 'Ma position actuelle',
          displayName: 'Utiliser le GPS de ce telephone',
          latitude: 0,
          longitude: 0,
          type: 'current_location',
        );
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
      duration: Duration(milliseconds: 180 + (index * 35).clamp(0, 180)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
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
        final alpha = 0.08 + (_controller.value * 0.10);
        return Container(
          height: 68,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B8A5A).withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(18),
          ),
        );
      },
    );
  }
}

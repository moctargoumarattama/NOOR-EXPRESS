import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/models/app_role.dart';
import '../../../../../core/network/api_error.dart';
import '../../../../../core/services/support_contact_service.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../core/location/location_quality.dart';
import '../../../../../shared/copy/ride_ui_copy.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/connectivity_fallback_view.dart';
import '../../../../../shared/widgets/notification_card.dart';
import '../../../../address_search/data/datasources/address_datasource.dart';
import '../../../../address_search/domain/entities/address_result.dart';
import '../../../../address_search/presentation/controllers/address_search_controller.dart';
import '../../../../address_search/presentation/screens/address_search_screen.dart';
import '../../../../map/presentation/controllers/map_controller.dart';
import '../../../../map/controllers/map_controller_provider.dart';
import '../../../../map/models/route_result.dart';
import '../../../../map/widgets/eta_overlay.dart';
import '../../../../ride_tracking/presentation/widgets/report_bottom_sheet.dart';
import '../../../../ride_tracking/data/datasources/tracking_remote_datasource.dart';
import '../../../../negotiation/data/datasources/negotiation_datasource.dart';
import '../../../../negotiation/data/models/ride_offer_model.dart';
import '../../data/models/client_ride.dart';
import '../client_active_ride_guard.dart';
import '../controllers/client_home_controller.dart';
import '../controllers/client_realtime_controller.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/hamburger_menu.dart';
import '../widgets/home_idle_sheet.dart';
import '../widgets/home_map_view.dart';
import '../widgets/search_bottom_sheet.dart';

part 'client_home_screen_helpers.dart';

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  final _mapKey = GlobalKey<HomeMapViewState>();
  final _priceController = TextEditingController();

  ProviderSubscription<ClientRealtimeState>? _realtimeSubscription;
  Timer? _notificationTimer;
  Timer? _priceEstimateDebounce;
  Timer? _driversRefreshTimer;
  AddressResult? _pickupAddress;
  AddressResult? _dropoffAddress;
  String? _notificationMessage;
  bool _isMenuOpen = false;
  bool _isApplyingSuggestedPrice = false;
  bool _priceManuallyEdited = false;
  int? _activeRideRouteSnapshotRideId;
  RouteResult? _activeRideRouteSnapshot;
  int? _homeOffersRideId;
  List<RideOfferModel> _homeOffers = const [];
  bool _isLoadingHomeOffers = false;
  int? _acceptingHomeOfferId;
  int? _rejectingHomeOfferId;
  bool _isDisposed = false;

  bool get _isUiMounted => mounted && !_isDisposed;

  @override
  void initState() {
    super.initState();
    _listenToRealtime();
    _priceController.addListener(_markPriceAsEdited);

    Future.microtask(_bootstrapHome);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _realtimeSubscription?.close();
    _notificationTimer?.cancel();
    _priceEstimateDebounce?.cancel();
    _driversRefreshTimer?.cancel();
    try {
      ref.read(clientRealtimeProvider.notifier).stop();
      ref.read(mapControllerProvider(MapMode.client).notifier).stop();
    } catch (_) {
      // Guard against late lifecycle callbacks when widget is tearing down.
    }
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final homeState = ref.watch(clientHomeControllerProvider);
    final mapState = ref.watch(mapControllerProvider(MapMode.client));
    final routeState = ref.watch(noorMapControllerProvider);
    final activeRide = homeState.activeRide;
    final pickupLocationQuality = _resolvedPickupLocationQuality(mapState);
    final pickupAccuracyMeters = _resolvedPickupAccuracyMeters(mapState);
    final showUnknownPositionCard =
        _shouldShowUnknownPositionCard(activeRide, pickupLocationQuality);
    final showApproximateBanner =
        _shouldShowApproximateBanner(activeRide, pickupLocationQuality);
    final canSubmitRideRequest = pickupLocationQuality != LocationQuality.unknown;
    final submitDisabledReason =
        _submitDisabledReasonForQuality(pickupLocationQuality);
    final addressSearchState = ref.watch(addressSearchControllerProvider);
    final favorites = addressSearchState.favorites;
    final recentAddresses = addressSearchState.recents;
    final displayName = _displayName(session);
    final initials = _initials(displayName);
    final startupIssueType = _startupIssueType(homeState);
    final startupIssueMessage = _startupIssueMessage(homeState.loadError);
    final showIdleSheet = activeRide == null && _dropoffAddress == null;
    _scheduleHomeOfferSync(activeRide);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: HomeMapView(
              key: _mapKey,
              clientPosition: mapState.currentPosition,
              locationQuality: pickupLocationQuality,
              locationAccuracyMeters: pickupAccuracyMeters,
              drivers: mapState.drivers,
              pickup: _pickupAddress,
              dropoff: _dropoffAddress,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FloatingTopBar(
                title: 'NOOR EXPRESS',
                initials: initials,
                hasNotification: _notificationMessage != null,
                onMenuTap: () => setState(() => _isMenuOpen = true),
                onProfileTap: () => context.push(AppRoutes.profile),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 238,
            child: _RecenterButton(onTap: _retryLocationAndRecenter),
          ),
          if (_notificationMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 88,
              left: 16,
              right: 16,
              child: NotificationCard(
                title: 'Nouvelle',
                message: _notificationMessage!,
                tone: _notificationToneForMessage(_notificationMessage!),
                compact: true,
              ),
            ),
          if (_notificationMessage == null && mapState.errorMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 88,
              left: 16,
              right: 16,
              child: NotificationCard(
                title: 'Position',
                message: _humanizeMessage(
                  mapState.errorMessage,
                  fallback: RideUiCopy.gpsUnavailable,
                ),
                tone: NotificationCardTone.warning,
                compact: true,
              ),
            ),
          if (_notificationMessage == null &&
              mapState.errorMessage == null &&
              routeState.route != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 88,
              left: 0,
              right: 0,
              child: Center(child: EtaOverlay(route: routeState.route)),
            ),
          if (showApproximateBanner)
            Positioned(
              left: 16,
              right: 16,
              bottom: showIdleSheet ? 108 : 238,
              child: const _ApproximateLocationBanner(),
            ),
          if (showUnknownPositionCard)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Center(
                  child: _UnknownLocationCard(
                    onTap: () => _openAddressSearch(AddressSearchMode.pickup),
                  ),
                ),
              ),
            ),
          if (showIdleSheet)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HomeIdleSheet(
                favorites: favorites,
                recents: recentAddresses,
                onSearchTap: () =>
                    _openAddressSearch(AddressSearchMode.dropoff),
                onFavoriteTap: _selectQuickDestination,
                onRecentTap: _selectQuickDestination,
              ),
            )
          else
            SearchBottomSheet(
              pickup: _pickupAddress,
              dropoff: _dropoffAddress,
              priceController: _priceController,
              isCreating: homeState.isCreating,
              isEstimatingPrice: homeState.isEstimatingPrice,
              estimate: homeState.priceEstimate,
              estimateError: homeState.priceEstimateError,
              route: routeState.route,
              routeError: routeState.errorMessage,
              activeRideRoute: activeRide?.id == _activeRideRouteSnapshotRideId
                  ? _activeRideRouteSnapshot
                  : null,
              recentAddresses: recentAddresses,
              nearbyDriversCount: mapState.drivers.length,
              offers:
                  activeRide?.id == _homeOffersRideId ? _homeOffers : const [],
              isLoadingOffers: _isLoadingHomeOffers,
              acceptingOfferId: _acceptingHomeOfferId,
              rejectingOfferId: _rejectingHomeOfferId,
              activeRide: activeRide,
              recentDepartureLabels: _recentDepartureLabels(homeState.rides),
              onPickupTap: () => _openAddressSearch(AddressSearchMode.pickup),
              onDropoffTap: () => _openAddressSearch(AddressSearchMode.dropoff),
              onRecentTap: _selectQuickDestination,
              onClearPickup: _clearPickup,
              onClearDropoff: _clearDropoff,
              onSubmit: _submitRide,
              onOpenActiveRide: () => _openRide(activeRide),
              onCancelActiveRide: () => _cancelActiveRide(activeRide),
              onAcceptOffer: _acceptHomeOffer,
              onRejectOffer: _rejectHomeOffer,
              onViewAllOffers: () => _openRide(activeRide),
              onAddToFavorites: _addDropoffToFavorites,
              pickupLocationQuality: pickupLocationQuality,
              canSubmitRideRequest: canSubmitRideRequest,
              submitDisabledReason: submitDisabledReason,
            ),
          HamburgerMenu(
            isOpen: _isMenuOpen,
            displayName: displayName,
            initials: initials,
            phoneNumber: session.phoneNumber ?? '',
            onClose: () => setState(() => _isMenuOpen = false),
            onProfileTap: () {
              setState(() => _isMenuOpen = false);
              context.push(AppRoutes.profile);
            },
            onHistoryTap: () {
              setState(() => _isMenuOpen = false);
              context.push(AppRoutes.clientHistory);
            },
            onNotificationsTap: () {
              setState(() => _isMenuOpen = false);
              context.push(AppRoutes.notifications);
            },
            onSettingsTap: () {
              setState(() => _isMenuOpen = false);
              context.push(AppRoutes.settings);
            },
            onHelpTap: () {
              setState(() => _isMenuOpen = false);
              context.push(AppRoutes.help);
            },
            onSupportTap: () {
              setState(() => _isMenuOpen = false);
              unawaited(_openSupportChat());
            },
            onPolicyTap: () {
              setState(() => _isMenuOpen = false);
              context.push(AppRoutes.usagePolicy);
            },
            onReportTap: _openGeneralReport,
            onDriverModeTap: () {
              setState(() => _isMenuOpen = false);
              context.go(AppRoutes.driverHome);
            },
            onLogout: () {
              setState(() => _isMenuOpen = false);
              ref.read(sessionControllerProvider.notifier).logout();
            },
          ),
          if (startupIssueType != null)
            Positioned.fill(
              child: ConnectivityFallbackView(
                issueType: startupIssueType,
                message: startupIssueMessage,
                onRetry: _retryHomeBootstrap,
              ),
            ),
        ],
      ),
    );
  }

  void _updateUi(VoidCallback callback) {
    if (_isUiMounted) {
      setState(callback);
    }
  }

  Future<void> _openSupportChat() async {
    final result = await ref
        .read(supportContactServiceProvider)
        .openSupportChat(AppRole.client);
    if (!mounted || !_isUiMounted || result.type != SupportContactResultType.failed) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Impossible d ouvrir WhatsApp pour le moment.',
      tone: AppSnackbarTone.error,
    );
  }

  Future<void> _retryLocationAndRecenter() async {
    AppSnackbar.show(
      context,
      message: 'On retrouve votre position...',
      tone: AppSnackbarTone.info,
    );
    await ref.read(mapControllerProvider(MapMode.client).notifier).start();
    if (!mounted || !_isUiMounted) {
      return;
    }
    _mapKey.currentState?.recenter();
    final mapState = ref.read(mapControllerProvider(MapMode.client));
    AppSnackbar.show(
      context,
      message: mapState.errorMessage ?? 'Votre position est a jour.',
      tone: mapState.errorMessage == null
          ? AppSnackbarTone.success
          : AppSnackbarTone.error,
    );
  }

  Future<void> _bootstrapHome() async {
    if (!_isUiMounted) {
      return;
    }
    await ref.read(clientHomeControllerProvider.notifier).loadRides();
    if (!_isUiMounted) {
      return;
    }
    final userId = ref.read(sessionControllerProvider).userId;
    if (userId != null) {
      await ref.read(clientRealtimeProvider.notifier).start(userId);
      if (!_isUiMounted) {
        return;
      }
    }
    final addressSearchController =
        ref.read(addressSearchControllerProvider.notifier);
    await addressSearchController.loadFavorites();
    await addressSearchController.loadRecents();
    if (!_isUiMounted) {
      return;
    }
    await ref.read(mapControllerProvider(MapMode.client).notifier).start();
    if (!_isUiMounted) {
      return;
    }
    _driversRefreshTimer?.cancel();
    _driversRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isUiMounted) {
        return;
      }
      ref.read(mapControllerProvider(MapMode.client).notifier).refreshDrivers(
            silent: true,
          );
    });
  }

  Future<void> _retryHomeBootstrap() async {
    AppSnackbar.show(
      context,
      message: RideUiCopy.refreshing,
      tone: AppSnackbarTone.info,
    );
    await _bootstrapHome();
  }

  ApiIssueType? _startupIssueType(ClientHomeState homeState) {
    if (homeState.isLoading) {
      return null;
    }
    if (homeState.activeRide != null || homeState.rides.isNotEmpty) {
      return null;
    }
    final issue = ApiErrorPayload.classifyMessage(homeState.loadError);
    return issue == ApiIssueType.unknown ? null : issue;
  }

  String? _startupIssueMessage(String? rawMessage) {
    final trimmed = rawMessage?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.my_location_rounded, color: Color(0xFF1B8A5A)),
        ),
      ),
    );
  }
}

class _ApproximateLocationBanner extends StatelessWidget {
  const _ApproximateLocationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3B34C)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFAD6800)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre position est approximative. Verifiez votre point de depart avant de continuer.',
              style: TextStyle(
                color: Color(0xFF6A4B00),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnknownLocationCard extends StatelessWidget {
  const _UnknownLocationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Position non disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF151B26),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre GPS ne repond pas. Recherchez votre adresse de depart manuellement.',
            style: TextStyle(
              color: Color(0xFF4A5568),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              child: const Text('Saisir mon adresse de depart'),
            ),
          ),
        ],
      ),
    );
  }
}

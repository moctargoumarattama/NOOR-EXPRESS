import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../shared/copy/ride_ui_copy.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/notification_card.dart';
import '../../../../address_search/domain/entities/address_result.dart';
import '../../../../address_search/presentation/screens/address_search_screen.dart';
import '../../../../map/presentation/controllers/map_controller.dart';
import '../../../../map/controllers/map_controller_provider.dart';
import '../../../../map/widgets/eta_overlay.dart';
import '../../../../ride_tracking/presentation/widgets/report_bottom_sheet.dart';
import '../../../../ride_tracking/data/datasources/tracking_remote_datasource.dart';
import '../../data/models/client_ride.dart';
import '../controllers/client_home_controller.dart';
import '../controllers/client_realtime_controller.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/hamburger_menu.dart';
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

  @override
  void initState() {
    super.initState();
    _listenToRealtime();
    _priceController.addListener(_markPriceAsEdited);

    Future.microtask(() async {
      await ref.read(clientHomeControllerProvider.notifier).loadRides();
      final userId = ref.read(sessionControllerProvider).userId;
      if (userId != null) {
        await ref.read(clientRealtimeProvider.notifier).start(userId);
      }
      await ref.read(mapControllerProvider(MapMode.client).notifier).start();
      _driversRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        ref.read(mapControllerProvider(MapMode.client).notifier).refreshDrivers(
              silent: true,
            );
      });
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.close();
    _notificationTimer?.cancel();
    _priceEstimateDebounce?.cancel();
    _driversRefreshTimer?.cancel();
    ref.read(clientRealtimeProvider.notifier).stop();
    ref.read(mapControllerProvider(MapMode.client).notifier).stop();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final homeState = ref.watch(clientHomeControllerProvider);
    final mapState = ref.watch(mapControllerProvider(MapMode.client));
    final route = ref.watch(noorMapControllerProvider.select((s) => s.route));
    final activeRide = _activeRide(homeState.rides);
    final displayName = _displayName(session);
    final initials = _initials(displayName);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: HomeMapView(
              key: _mapKey,
              clientPosition: mapState.currentPosition,
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
              route != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 88,
              left: 0,
              right: 0,
              child: Center(child: EtaOverlay(route: route)),
            ),
          SearchBottomSheet(
            pickup: _pickupAddress,
            dropoff: _dropoffAddress,
            priceController: _priceController,
            isCreating: homeState.isCreating,
            isEstimatingPrice: homeState.isEstimatingPrice,
            estimate: homeState.priceEstimate,
            estimateError: homeState.priceEstimateError,
            activeRide: activeRide,
            onPickupTap: () => _openAddressSearch(AddressSearchMode.pickup),
            onDropoffTap: () => _openAddressSearch(AddressSearchMode.dropoff),
            onClearPickup: _clearPickup,
            onClearDropoff: _clearDropoff,
            onSubmit: _submitRide,
            onOpenActiveRide: () => _openRide(activeRide),
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
        ],
      ),
    );
  }

  void _updateUi(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }

  Future<void> _retryLocationAndRecenter() async {
    AppSnackbar.show(
      context,
      message: 'On retrouve votre position...',
      tone: AppSnackbarTone.info,
    );
    await ref.read(mapControllerProvider(MapMode.client).notifier).start();
    if (!mounted) {
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

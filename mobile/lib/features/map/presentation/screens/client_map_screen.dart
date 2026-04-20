import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/location/device_location_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_surface_card.dart';
import '../../../../shared/widgets/notification_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../home/client/data/models/client_ride.dart';
import '../../../home/client/presentation/controllers/client_home_controller.dart';
import '../../../home/client/presentation/controllers/client_realtime_controller.dart';
import '../controllers/map_controller.dart';
import '../widgets/web_map_surface.dart';

class ClientMapScreen extends ConsumerStatefulWidget {
  const ClientMapScreen({super.key});

  @override
  ConsumerState<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends ConsumerState<ClientMapScreen> {
  static const LatLng _fallbackCenter = LatLng(33.5731, -7.5898);

  ProviderSubscription<ClientRealtimeState>? _clientRealtimeSubscription;
  Timer? _notificationTimer;
  String? _notificationMessage;
  GoogleMapController? _googleMapController;
  bool _cameraPrimed = false;

  @override
  void initState() {
    super.initState();
    _clientRealtimeSubscription = ref.listenManual<ClientRealtimeState>(
      clientRealtimeProvider,
      (previous, next) {
        final position = next.lastDriverPosition;
        if (position != null && position != previous?.lastDriverPosition) {
          ref
              .read(mapControllerProvider(MapMode.client).notifier)
              .applyDriverPositionUpdate(position);
          ref.read(clientRealtimeProvider.notifier).consumeDriverPosition();
        }

        final message = next.lastMessage;
        if (message == null || message == previous?.lastMessage || !mounted) {
          return;
        }

        _showSnackBar(message);
        _showNotification(message);
        ref.read(clientRealtimeProvider.notifier).consumeMessage();
      },
    );

    Future.microtask(() async {
      await ref.read(clientHomeControllerProvider.notifier).loadRides();
      final session = ref.read(sessionControllerProvider);
      if (session.userId != null) {
        await ref.read(clientRealtimeProvider.notifier).start(session.userId!);
      }
      await ref.read(mapControllerProvider(MapMode.client).notifier).start();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _clientRealtimeSubscription?.close();
    ref.read(clientRealtimeProvider.notifier).stop();
    ref.read(mapControllerProvider(MapMode.client).notifier).stop();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    AppSnackbar.show(
      context,
      message: message,
      tone: _snackbarToneForMessage(message),
    );
  }

  void _showNotification(String message) {
    setState(() {
      _notificationMessage = message;
    });
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationMessage = null;
      });
    });
  }

  AppSnackbarTone _snackbarToneForMessage(String message) {
    final value = message.toLowerCase();
    if (value.contains('terminee') || value.contains('acceptee')) {
      return AppSnackbarTone.success;
    }
    if (value.contains('annulee')) {
      return AppSnackbarTone.error;
    }
    return AppSnackbarTone.info;
  }

  NotificationCardTone _notificationToneForMessage(String message) {
    final value = message.toLowerCase();
    if (value.contains('terminee') || value.contains('acceptee')) {
      return NotificationCardTone.success;
    }
    if (value.contains('annulee')) {
      return NotificationCardTone.error;
    }
    return NotificationCardTone.info;
  }

  Future<void> _recenter() async {
    final point =
        ref.read(mapControllerProvider(MapMode.client)).currentPosition;
    if (point == null) {
      return;
    }

    await _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(point.latitude, point.longitude),
        15.2,
      ),
    );
  }

  Set<Marker> _buildMarkers(MapState mapState) {
    final markers = <Marker>{};

    final currentPosition = mapState.currentPosition;
    if (currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('client'),
          position: LatLng(currentPosition.latitude, currentPosition.longitude),
          infoWindow: const InfoWindow(title: 'Votre position'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    for (final driver in mapState.drivers) {
      markers.add(
        Marker(
          markerId: MarkerId('driver-${driver.driverId}'),
          position: LatLng(
            driver.position.latitude,
            driver.position.longitude,
          ),
          infoWindow: InfoWindow(title: 'Driver #${driver.driverId}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMapCanvas(MapState mapState, LatLng cameraCenter) {
    if (kIsWeb) {
      return WebMapSurface(
        center: mapState.currentPosition,
        drivers: mapState.drivers,
        primaryLabel: 'Vous',
        primaryColor: const Color(0xFF315DB7),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: cameraCenter,
        zoom: 13.8,
      ),
      myLocationEnabled:
          mapState.accessState == DeviceLocationAccessState.granted,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      markers: _buildMarkers(mapState),
      onMapCreated: (controller) {
        _googleMapController = controller;
        if (!_cameraPrimed && mapState.currentPosition != null) {
          _cameraPrimed = true;
          unawaited(_recenter());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider(MapMode.client));
    final homeState = ref.watch(clientHomeControllerProvider);
    final realtimeState = ref.watch(clientRealtimeProvider);
    final latestRide = homeState.rides.isEmpty ? null : homeState.rides.first;
    final cameraCenter = mapState.currentPosition == null
        ? _fallbackCenter
        : LatLng(
            mapState.currentPosition!.latitude,
            mapState.currentPosition!.longitude,
          );

    return Scaffold(
      body: Stack(
        children: [
          _buildMapCanvas(mapState, cameraCenter),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MapCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () {
                          context.go(AppRoutes.clientHome);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RealtimeChip(
                          label: _labelForConnection(
                              realtimeState.connectionStatus),
                          color: _colorForConnection(
                              realtimeState.connectionStatus),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MapCircleButton(
                        icon: Icons.my_location_rounded,
                        onPressed: _recenter,
                      ),
                    ],
                  ),
                  if (_notificationMessage != null) ...[
                    const SizedBox(height: 16),
                    NotificationCard(
                      title: 'Mise a jour live',
                      message: _notificationMessage!,
                      tone: _notificationToneForMessage(_notificationMessage!),
                    ),
                  ],
                  if (mapState.errorMessage != null &&
                      mapState.currentPosition == null) ...[
                    const SizedBox(height: 16),
                    _LocationAccessCard(
                      message: mapState.errorMessage!,
                      onOpenAppSettings: () {
                        ref
                            .read(
                                mapControllerProvider(MapMode.client).notifier)
                            .openAppSettings();
                      },
                      onOpenLocationSettings: () {
                        ref
                            .read(
                                mapControllerProvider(MapMode.client).notifier)
                            .openLocationSettings();
                      },
                    ),
                  ],
                  const Spacer(),
                  _ClientMapBottomSheet(
                    ride: latestRide,
                    connectedDrivers: mapState.drivers.length,
                    isRefreshingDrivers: mapState.isRefreshingDrivers,
                    onOrderPressed: () {
                      context.go(AppRoutes.clientHome);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForConnection(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.connected:
        return 'Temps reel connecte';
      case WebSocketStatus.connecting:
        return 'Connexion...';
      case WebSocketStatus.reconnecting:
        return 'Reconnexion...';
      case WebSocketStatus.disconnected:
        return 'Live hors ligne';
    }
  }

  Color _colorForConnection(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.connected:
        return AppColors.emerald;
      case WebSocketStatus.connecting:
      case WebSocketStatus.reconnecting:
        return const Color(0xFF315DB7);
      case WebSocketStatus.disconnected:
        return AppColors.coral;
    }
  }
}

class _ClientMapBottomSheet extends StatelessWidget {
  const _ClientMapBottomSheet({
    required this.ride,
    required this.connectedDrivers,
    required this.isRefreshingDrivers,
    required this.onOrderPressed,
  });

  final ClientRide? ride;
  final int connectedDrivers;
  final bool isRefreshingDrivers;
  final VoidCallback onOrderPressed;

  @override
  Widget build(BuildContext context) {
    final config = _configForRide(ride);

    return AppSurfaceCard(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Column(
          key: ValueKey(ride?.status ?? 'idle'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: config.iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: config.showLoader
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Icon(config.icon, color: config.iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (ride != null) StatusBadge(status: ride!.status),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    'Drivers connectes: $connectedDrivers',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (isRefreshingDrivers)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                ],
              ),
            ),
            if (ride != null) ...[
              const SizedBox(height: 14),
              Text(
                '${ride!.pickupLocation} -> ${ride!.dropoffLocation}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              label: ride == null ? 'Commander' : config.ctaLabel,
              onPressed: onOrderPressed,
            ),
          ],
        ),
      ),
    );
  }

  _RidePanelConfig _configForRide(ClientRide? ride) {
    if (ride == null) {
      return const _RidePanelConfig(
        title: 'Pret a commander',
        subtitle: 'Visualise les drivers autour de toi puis ouvre le booking.',
        ctaLabel: 'Commander',
        icon: Icons.local_taxi_rounded,
        iconBackground: Color(0xFFFFF6E3),
        iconColor: Color(0xFF9B6A00),
      );
    }

    switch (ride.status) {
      case 'pending':
        return const _RidePanelConfig(
          title: 'Recherche de chauffeur',
          subtitle:
              'Nous cherchons le meilleur driver disponible autour de toi.',
          ctaLabel: 'Voir la course',
          icon: Icons.search_rounded,
          iconBackground: Color(0xFFFFF6E3),
          iconColor: Color(0xFF9B6A00),
          showLoader: true,
        );
      case 'accepted':
        return const _RidePanelConfig(
          title: 'Un chauffeur a accepte',
          subtitle: 'La course est confirmee. Le tracking continue en direct.',
          ctaLabel: 'Voir les details',
          icon: Icons.check_circle_rounded,
          iconBackground: Color(0xFFEFF4FF),
          iconColor: Color(0xFF315DB7),
        );
      case 'started':
        return const _RidePanelConfig(
          title: 'Course en cours',
          subtitle:
              'Le trajet a commence. Garde la carte ouverte pour suivre l activite live.',
          ctaLabel: 'Suivre la course',
          icon: Icons.route_rounded,
          iconBackground: Color(0xFFF1EBFF),
          iconColor: Color(0xFF6A42C2),
        );
      case 'completed':
        return const _RidePanelConfig(
          title: 'Course terminee',
          subtitle:
              'Le trajet est termine. Tu peux deja commander une nouvelle course.',
          ctaLabel: 'Commander a nouveau',
          icon: Icons.flag_rounded,
          iconBackground: Color(0xFFE7F7F1),
          iconColor: AppColors.emerald,
        );
      case 'cancelled':
      case 'expired':
        return const _RidePanelConfig(
          title: 'Course indisponible',
          subtitle:
              'La demande a ete annulee ou expiree. Tu peux relancer une nouvelle commande.',
          ctaLabel: 'Commander a nouveau',
          icon: Icons.error_rounded,
          iconBackground: Color(0xFFFFF1F0),
          iconColor: AppColors.coral,
        );
      default:
        return const _RidePanelConfig(
          title: 'Tracking live',
          subtitle: 'Le statut de ta ride est mis a jour en direct.',
          ctaLabel: 'Voir les details',
          icon: Icons.notifications_active_rounded,
          iconBackground: Color(0xFFEFF4FF),
          iconColor: Color(0xFF315DB7),
        );
    }
  }
}

class _RidePanelConfig {
  const _RidePanelConfig({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.showLoader = false,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final bool showLoader;
}

class _RealtimeChip extends StatelessWidget {
  const _RealtimeChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _LocationAccessCard extends StatelessWidget {
  const _LocationAccessCard({
    required this.message,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  final String message;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Localisation requise',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Reglages app',
                  onPressed: onOpenAppSettings,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Activer GPS',
                  onPressed: onOpenLocationSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

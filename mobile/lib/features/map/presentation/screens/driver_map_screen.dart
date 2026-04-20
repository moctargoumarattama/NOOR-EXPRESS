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
import '../../../home/driver/data/models/driver_ride.dart';
import '../../../home/driver/presentation/controllers/driver_controller.dart';
import '../../../home/driver/presentation/controllers/driver_realtime_controller.dart';
import '../../../home/driver/presentation/controllers/ride_driver_controller.dart';
import '../controllers/map_controller.dart';
import '../widgets/web_map_surface.dart';

class DriverMapScreen extends ConsumerStatefulWidget {
  const DriverMapScreen({super.key});

  @override
  ConsumerState<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends ConsumerState<DriverMapScreen> {
  static const LatLng _fallbackCenter = LatLng(33.5731, -7.5898);

  ProviderSubscription<DriverRealtimeState>? _driverRealtimeSubscription;
  Timer? _notificationTimer;
  String? _notificationMessage;
  GoogleMapController? _googleMapController;
  bool _cameraPrimed = false;

  @override
  void initState() {
    super.initState();
    _driverRealtimeSubscription = ref.listenManual<DriverRealtimeState>(
      driverRealtimeProvider,
      (previous, next) {
        final message = next.lastMessage;
        if (message == null || message == previous?.lastMessage || !mounted) {
          return;
        }

        _showSnackBar(message);
        _showNotification(message);
        ref.read(driverRealtimeProvider.notifier).consumeMessage();
      },
    );

    Future.microtask(() async {
      await Future.wait([
        ref.read(driverProvider.notifier).loadProfile(),
        ref.read(rideDriverProvider.notifier).loadRides(),
      ]);

      final session = ref.read(sessionControllerProvider);
      if (session.userId != null) {
        await ref.read(driverRealtimeProvider.notifier).start(session.userId!);
      }
      await ref.read(mapControllerProvider(MapMode.driver).notifier).start();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _driverRealtimeSubscription?.close();
    ref.read(driverRealtimeProvider.notifier).stop();
    ref.read(mapControllerProvider(MapMode.driver).notifier).stop();
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
    if (value.contains('nouvelle demande')) {
      return AppSnackbarTone.info;
    }
    if (value.contains('annulee')) {
      return AppSnackbarTone.error;
    }
    return AppSnackbarTone.success;
  }

  NotificationCardTone _notificationToneForMessage(String message) {
    final value = message.toLowerCase();
    if (value.contains('nouvelle demande')) {
      return NotificationCardTone.warning;
    }
    if (value.contains('annulee')) {
      return NotificationCardTone.error;
    }
    return NotificationCardTone.success;
  }

  Future<void> _recenter() async {
    final point =
        ref.read(mapControllerProvider(MapMode.driver)).currentPosition;
    if (point == null) {
      return;
    }

    await _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(point.latitude, point.longitude),
        15.8,
      ),
    );
  }

  DriverRide? _activeRide(List<DriverRide> rides) {
    for (final ride in rides) {
      if (ride.status == 'accepted' || ride.status == 'started') {
        return ride;
      }
    }
    return null;
  }

  Widget _buildMapCanvas(MapState mapState, LatLng cameraCenter) {
    final currentPosition = mapState.currentPosition;

    if (kIsWeb) {
      return WebMapSurface(
        center: currentPosition,
        drivers: const [],
        primaryLabel: 'Driver',
        primaryColor: AppColors.emerald,
      );
    }

    final markers = <Marker>{
      if (currentPosition != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(currentPosition.latitude, currentPosition.longitude),
          infoWindow: const InfoWindow(title: 'Votre position driver'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: cameraCenter,
        zoom: 14.4,
      ),
      myLocationEnabled:
          mapState.accessState == DeviceLocationAccessState.granted,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      markers: markers,
      onMapCreated: (controller) {
        _googleMapController = controller;
        if (!_cameraPrimed && currentPosition != null) {
          _cameraPrimed = true;
          unawaited(_recenter());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider(MapMode.driver));
    final driverState = ref.watch(driverProvider);
    final ridesState = ref.watch(rideDriverProvider);
    final realtimeState = ref.watch(driverRealtimeProvider);
    final profile = driverState.profile;
    final activeRide = _activeRide(ridesState.rides);

    final currentPosition = mapState.currentPosition;
    final cameraCenter = currentPosition == null
        ? _fallbackCenter
        : LatLng(currentPosition.latitude, currentPosition.longitude);

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
                      _DriverMapCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () {
                          context.go(AppRoutes.driverHome);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DriverMapChip(
                          label: _labelForConnection(
                              realtimeState.connectionStatus),
                          color: _colorForConnection(
                              realtimeState.connectionStatus),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _DriverMapCircleButton(
                        icon: Icons.my_location_rounded,
                        onPressed: _recenter,
                      ),
                    ],
                  ),
                  if (_notificationMessage != null) ...[
                    const SizedBox(height: 16),
                    NotificationCard(
                      title: 'Activite driver',
                      message: _notificationMessage!,
                      tone: _notificationToneForMessage(_notificationMessage!),
                    ),
                  ],
                  if (mapState.errorMessage != null &&
                      mapState.currentPosition == null) ...[
                    const SizedBox(height: 16),
                    _DriverLocationCard(
                      message: mapState.errorMessage!,
                      onOpenAppSettings: () {
                        ref
                            .read(
                                mapControllerProvider(MapMode.driver).notifier)
                            .openAppSettings();
                      },
                      onOpenLocationSettings: () {
                        ref
                            .read(
                                mapControllerProvider(MapMode.driver).notifier)
                            .openLocationSettings();
                      },
                    ),
                  ],
                  const Spacer(),
                  _DriverMapBottomSheet(
                    driverPhone: profile?.phoneNumber ?? 'driver',
                    driverStatus: profile?.driverStatus ?? 'offline',
                    activeRide: activeRide,
                    isTracking: mapState.isTrackingPosition,
                    onOpenDashboard: () {
                      context.go(AppRoutes.driverHome);
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
        return 'Tracking live actif';
      case WebSocketStatus.connecting:
        return 'Connexion...';
      case WebSocketStatus.reconnecting:
        return 'Reconnexion...';
      case WebSocketStatus.disconnected:
        return 'Tracking interrompu';
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

class _DriverMapBottomSheet extends StatelessWidget {
  const _DriverMapBottomSheet({
    required this.driverPhone,
    required this.driverStatus,
    required this.activeRide,
    required this.isTracking,
    required this.onOpenDashboard,
  });

  final String driverPhone;
  final String driverStatus;
  final DriverRide? activeRide;
  final bool isTracking;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF7F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver $driverPhone',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isTracking
                          ? 'Ta position GPS est envoyee en direct.'
                          : 'Le tracking GPS attend encore la localisation.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _DriverStatusBadge(status: driverStatus),
            ],
          ),
          const SizedBox(height: 18),
          if (activeRide == null)
            Text(
              'Aucune course active pour le moment. Reste sur la carte pour partager ta position live.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else ...[
            Text(
              'Course active',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${activeRide!.pickupLocation} -> ${activeRide!.dropoffLocation}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            StatusBadge(status: activeRide!.status),
          ],
          const SizedBox(height: 18),
          AppButton.secondary(
            label: 'Retour au dashboard',
            onPressed: onOpenDashboard,
          ),
        ],
      ),
    );
  }
}

class _DriverMapChip extends StatelessWidget {
  const _DriverMapChip({
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

class _DriverMapCircleButton extends StatelessWidget {
  const _DriverMapCircleButton({
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

class _DriverLocationCard extends StatelessWidget {
  const _DriverLocationCard({
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
            'Localisation driver requise',
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

class _DriverStatusBadge extends StatelessWidget {
  const _DriverStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'online' => AppColors.emerald,
      'busy' => const Color(0xFF315DB7),
      _ => AppColors.coral,
    };

    final label = switch (status) {
      'online' => 'Online',
      'busy' => 'Busy',
      _ => 'Offline',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

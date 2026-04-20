import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/map/tile_cache_service.dart';
import '../../../../address_search/domain/entities/address_result.dart';
import '../../../../map/data/models/map_point.dart';
import '../../../../map/data/models/realtime_driver_marker.dart';
import '../../../../map/controllers/map_controller_provider.dart';
import '../../../../map/widgets/drivers_layer.dart';
import '../../../../map/widgets/eta_overlay.dart';
import '../../../../map/widgets/pulse_marker.dart';
import '../../../../map/widgets/route_layer.dart';

class HomeMapView extends ConsumerStatefulWidget {
  const HomeMapView({
    super.key,
    required this.drivers,
    this.clientPosition,
    this.pickup,
    this.dropoff,
  });

  final MapPoint? clientPosition;
  final AddressResult? pickup;
  final AddressResult? dropoff;
  final List<RealtimeDriverMarker> drivers;

  @override
  ConsumerState<HomeMapView> createState() => HomeMapViewState();
}

class HomeMapViewState extends ConsumerState<HomeMapView> {
  static const _niameyCenter = LatLng(13.5137, 2.1098);
  final MapController _controller = MapController();

  void recenter() {
    final target = _clientPoint;
    _controller.move(target, 14.8);
  }

  @override
  void didUpdateWidget(covariant HomeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.dropoff != widget.dropoff ||
        oldWidget.clientPosition != widget.clientPosition) {
      _refreshRoute();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final noorMapState = ref.watch(noorMapControllerProvider);

    return Stack(
      children: [
        RepaintBoundary(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _clientPoint,
              initialZoom: 14,
              minZoom: 10,
              maxZoom: 19,
              keepAlive: true,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom |
                    InteractiveFlag.pinchMove,
                rotationThreshold: 20,
                pinchZoomThreshold: 0.5,
              ),
              onMapReady: _fitFocus,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.noorexpress.app',
                tileProvider: createNoorTileProvider(),
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),
              RouteLayer(route: noorMapState.route),
              MarkerLayer(markers: _markers),
              DriversLayer(drivers: widget.drivers),
            ],
          ),
        ),
        _ZoomControls(
          onZoomIn: () => _zoomBy(1),
          onZoomOut: () => _zoomBy(-1),
        ),
      ],
    );
  }

  void _zoomBy(double delta) {
    _controller.move(
      _controller.camera.center,
      (_controller.camera.zoom + delta).clamp(10, 19),
    );
  }

  LatLng get _clientPoint {
    final current = widget.clientPosition;
    if (current != null) {
      return LatLng(current.latitude, current.longitude);
    }
    final pickup = widget.pickup;
    if (pickup != null) {
      return LatLng(pickup.latitude, pickup.longitude);
    }
    return _niameyCenter;
  }

  List<LatLng> get _focusPoints {
    return [
      _clientPoint,
      _addressPoint(widget.pickup),
      _addressPoint(widget.dropoff),
    ].whereType<LatLng>().toList();
  }

  List<Marker> get _markers {
    final pickup = _addressPoint(widget.pickup);
    final dropoff = _addressPoint(widget.dropoff);

    return [
      Marker(
        point: _clientPoint,
        width: 74,
        height: 74,
        child: const PulseMarker(),
      ),
      if (pickup != null)
        _pinMarker(
          point: pickup,
          color: const Color(0xFF1B8A5A),
          icon: Icons.trip_origin_rounded,
        ),
      if (dropoff != null)
        _pinMarker(
          point: dropoff,
          color: const Color(0xFFE5484D),
          icon: Icons.flag_rounded,
        ),
    ];
  }

  Widget buildEtaOverlay() {
    final route = ref.watch(noorMapControllerProvider.select((s) => s.route));
    return EtaOverlay(route: route);
  }

  Marker _pinMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
  }) {
    return Marker(
      point: point,
      width: 54,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  LatLng? _addressPoint(AddressResult? result) {
    if (result == null) {
      return null;
    }
    return LatLng(result.latitude, result.longitude);
  }

  void _fitFocus() {
    final points = _focusPoints;
    if (!mounted || points.isEmpty) {
      return;
    }
    try {
      if (points.length == 1) {
        _controller.move(points.first, 14.8);
        return;
      }
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(56, 120, 56, 260),
        ),
      );
    } catch (_) {
      return;
    }
  }

  void _refreshRoute() {
    final pickup = _addressPoint(widget.pickup);
    final dropoff = _addressPoint(widget.dropoff);
    if (pickup == null || dropoff == null) {
      ref.read(noorMapControllerProvider.notifier).clearRoute();
      return;
    }
    ref.read(noorMapControllerProvider.notifier).calculateRoute(
          origin: pickup,
          destination: dropoff,
        );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 220,
      child: Column(
        children: [
          _ZoomButton(icon: Icons.add, onTap: onZoomIn),
          const SizedBox(height: 4),
          _ZoomButton(icon: Icons.remove, onTap: onZoomOut),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}

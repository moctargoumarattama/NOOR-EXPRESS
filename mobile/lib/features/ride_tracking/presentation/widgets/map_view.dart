import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/map/tile_cache_service.dart';
import '../../data/models/ride_tracking_model.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.status,
    this.currentPosition,
    this.driverPosition,
    this.pickupPosition,
    this.destinationPosition,
    this.driverHeadingDegrees,
  });

  final RideTrackingStatus status;
  final TrackingCoordinates? currentPosition;
  final TrackingCoordinates? driverPosition;
  final TrackingCoordinates? pickupPosition;
  final TrackingCoordinates? destinationPosition;
  final double? driverHeadingDegrees;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const _fallbackNiamey = LatLng(13.5116, 2.1254);
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverPosition != widget.driverPosition ||
        oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.destinationPosition != widget.destinationPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
    }
  }

  void _fitMap() {
    final points = _focusPoints;
    if (points.isEmpty) {
      return;
    }
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 15.2);
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(64),
        ),
      );
    } catch (_) {
      return;
    }
  }

  List<LatLng> get _focusPoints => [
        _toLatLng(widget.driverPosition),
        _toLatLng(widget.currentPosition),
        _toLatLng(widget.pickupPosition),
        _toLatLng(widget.destinationPosition),
      ].whereType<LatLng>().toList();

  List<Polyline> get _polylines {
    final pickup = _toLatLng(widget.pickupPosition);
    final destination = _toLatLng(widget.destinationPosition);
    final driver = _toLatLng(widget.driverPosition);

    if ((widget.status == RideTrackingStatus.accepted ||
            widget.status == RideTrackingStatus.arrived) &&
        driver != null &&
        pickup != null) {
      return [
        Polyline(
          points: [driver, pickup],
          strokeWidth: 5,
          color: const Color(0xFFF5A623),
        ),
      ];
    }

    if (widget.status == RideTrackingStatus.started &&
        pickup != null &&
        destination != null) {
      return [
        Polyline(
          points: [pickup, destination],
          strokeWidth: 5,
          color: const Color(0xFF1B8A5A),
        ),
      ];
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final center = _focusPoints.isEmpty ? _fallbackNiamey : _focusPoints.first;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0F1826)),
      child: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
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
                onMapReady: _fitMap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.noorexpress.app',
                  tileProvider: _tileProvider,
                  evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                ),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 220,
            child: Column(
              children: [
                _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                const SizedBox(height: 4),
                _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _zoomBy(double delta) {
    _mapController.move(
      _mapController.camera.center,
      (_mapController.camera.zoom + delta).clamp(10, 19),
    );
  }

  TileProvider get _tileProvider => createNoorTileProvider();

  List<Marker> _buildMarkers() {
    final shouldShowCurrent = widget.currentPosition != null &&
        !_samePoint(widget.currentPosition, widget.pickupPosition);

    return [
      if (shouldShowCurrent)
        _marker(
          point: widget.currentPosition!,
          color: const Color(0xFF315DB7),
          icon: Icons.my_location_rounded,
        ),
      if (widget.pickupPosition != null)
        _marker(
          point: widget.pickupPosition!,
          color: const Color(0xFF1B8A5A),
          icon: Icons.trip_origin_rounded,
        ),
      if (widget.destinationPosition != null)
        _marker(
          point: widget.destinationPosition!,
          color: const Color(0xFFF5A623),
          icon: Icons.flag_rounded,
        ),
      if (widget.driverPosition != null)
        _marker(
          point: widget.driverPosition!,
          color: const Color(0xFF1B8A5A),
          icon: Icons.navigation_rounded,
          rotationDegrees: widget.driverHeadingDegrees,
        ),
    ];
  }

  Marker _marker({
    required TrackingCoordinates point,
    required Color color,
    required IconData icon,
    double? rotationDegrees,
  }) {
    return Marker(
      point: LatLng(point.latitude, point.longitude),
      width: 54,
      height: 54,
      child: Center(
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: ((rotationDegrees ?? 0) * 3.1415926535) / 180,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  LatLng? _toLatLng(TrackingCoordinates? point) {
    if (point == null) {
      return null;
    }
    return LatLng(point.latitude, point.longitude);
  }

  bool _samePoint(TrackingCoordinates? left, TrackingCoordinates? right) {
    if (left == null || right == null) {
      return false;
    }
    final latitudeDelta = (left.latitude - right.latitude).abs();
    final longitudeDelta = (left.longitude - right.longitude).abs();
    return latitudeDelta < 0.0001 && longitudeDelta < 0.0001;
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/map/tile_cache_service.dart';
import '../../data/models/ride_tracking_model.dart';

enum TrackingPulseAnchor {
  none,
  current,
  pickup,
  driver,
}

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
  static const _cameraPadding = EdgeInsets.fromLTRB(56, 132, 56, 300);
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shouldRefitTrackingViewport(
      previousDriverPosition: oldWidget.driverPosition,
      nextDriverPosition: widget.driverPosition,
      previousCurrentPosition: oldWidget.currentPosition,
      nextCurrentPosition: widget.currentPosition,
      previousPickupPosition: oldWidget.pickupPosition,
      nextPickupPosition: widget.pickupPosition,
      previousDestinationPosition: oldWidget.destinationPosition,
      nextDestinationPosition: widget.destinationPosition,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
    }
  }

  void _fitMap() {
    if (!mounted) {
      return;
    }
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
          padding: _cameraPadding,
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
    final pulseAnchor = resolveTrackingPulseAnchor(
      status: widget.status,
      currentPosition: widget.currentPosition,
      driverPosition: widget.driverPosition,
      pickupPosition: widget.pickupPosition,
    );
    final shouldShowCurrent = widget.currentPosition != null &&
        !_samePoint(widget.currentPosition, widget.pickupPosition);

    return [
      if (shouldShowCurrent)
        _marker(
          point: widget.currentPosition!,
          color: const Color(0xFF315DB7),
          icon: Icons.my_location_rounded,
          showPulse: pulseAnchor == TrackingPulseAnchor.current,
        ),
      if (widget.pickupPosition != null)
        _marker(
          point: widget.pickupPosition!,
          color: const Color(0xFF1B8A5A),
          icon: Icons.trip_origin_rounded,
          showPulse: pulseAnchor == TrackingPulseAnchor.pickup,
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
          showPulse: pulseAnchor == TrackingPulseAnchor.driver,
        ),
    ];
  }

  Marker _marker({
    required TrackingCoordinates point,
    required Color color,
    required IconData icon,
    double? rotationDegrees,
    bool showPulse = false,
  }) {
    return Marker(
      point: LatLng(point.latitude, point.longitude),
      width: showPulse ? 80 : 54,
      height: showPulse ? 80 : 54,
      child: Center(
        child: RepaintBoundary(
          child: _TrackingPulseMarker(
            color: color,
            icon: icon,
            rotationDegrees: rotationDegrees,
            showPulse: showPulse,
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
    return trackingCoordinatesEqual(left, right);
  }
}

TrackingPulseAnchor resolveTrackingPulseAnchor({
  required RideTrackingStatus status,
  required TrackingCoordinates? currentPosition,
  required TrackingCoordinates? driverPosition,
  required TrackingCoordinates? pickupPosition,
}) {
  switch (status) {
    case RideTrackingStatus.pending:
    case RideTrackingStatus.offered:
      if (pickupPosition != null) {
        return TrackingPulseAnchor.pickup;
      }
      if (currentPosition != null) {
        return TrackingPulseAnchor.current;
      }
      return TrackingPulseAnchor.none;
    case RideTrackingStatus.accepted:
    case RideTrackingStatus.arrived:
    case RideTrackingStatus.started:
      if (driverPosition != null) {
        return TrackingPulseAnchor.driver;
      }
      if (pickupPosition != null) {
        return TrackingPulseAnchor.pickup;
      }
      if (currentPosition != null) {
        return TrackingPulseAnchor.current;
      }
      return TrackingPulseAnchor.none;
    case RideTrackingStatus.completed:
    case RideTrackingStatus.cancelled:
    case RideTrackingStatus.expired:
    case RideTrackingStatus.unknown:
      return TrackingPulseAnchor.none;
  }
}

class _TrackingPulseMarker extends StatefulWidget {
  const _TrackingPulseMarker({
    required this.color,
    required this.icon,
    required this.showPulse,
    this.rotationDegrees,
  });

  final Color color;
  final IconData icon;
  final bool showPulse;
  final double? rotationDegrees;

  @override
  State<_TrackingPulseMarker> createState() => _TrackingPulseMarkerState();
}

class _TrackingPulseMarkerState extends State<_TrackingPulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.showPulse) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _TrackingPulseMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse == oldWidget.showPulse) {
      return;
    }
    if (widget.showPulse) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marker = Transform.rotate(
      angle: ((widget.rotationDegrees ?? 0) * 3.1415926535) / 180,
      child: Container(
        key: widget.showPulse
            ? ValueKey('tracking-pulse-${widget.icon.codePoint}')
            : null,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(widget.icon, size: 20, color: Colors.white),
      ),
    );

    if (!widget.showPulse) {
      return marker;
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: AnimatedBuilder(
        animation: _controller,
        child: marker,
        builder: (context, child) {
          final progress = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.08),
                ),
              ),
              _TrackingPulseRing(
                color: widget.color,
                progress: progress,
              ),
              child!,
            ],
          );
        },
      ),
    );
  }
}

class _TrackingPulseRing extends StatelessWidget {
  const _TrackingPulseRing({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = 34 + (progress * 32);
    final opacity = (1 - progress).clamp(0.0, 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16 * opacity),
        border: Border.all(
          color: color.withValues(alpha: 0.38 * opacity),
          width: 1.8,
        ),
      ),
    );
  }
}

bool shouldRefitTrackingViewport({
  required TrackingCoordinates? previousDriverPosition,
  required TrackingCoordinates? nextDriverPosition,
  required TrackingCoordinates? previousCurrentPosition,
  required TrackingCoordinates? nextCurrentPosition,
  required TrackingCoordinates? previousPickupPosition,
  required TrackingCoordinates? nextPickupPosition,
  required TrackingCoordinates? previousDestinationPosition,
  required TrackingCoordinates? nextDestinationPosition,
}) {
  if (_presenceChanged(previousDriverPosition, nextDriverPosition) ||
      _presenceChanged(previousCurrentPosition, nextCurrentPosition) ||
      _presenceChanged(previousPickupPosition, nextPickupPosition) ||
      _presenceChanged(
        previousDestinationPosition,
        nextDestinationPosition,
      )) {
    return true;
  }

  return !trackingCoordinatesEqual(previousPickupPosition, nextPickupPosition) ||
      !trackingCoordinatesEqual(
        previousDestinationPosition,
        nextDestinationPosition,
      );
}

bool _presenceChanged(
  TrackingCoordinates? previous,
  TrackingCoordinates? next,
) {
  return (previous == null) != (next == null);
}

bool trackingCoordinatesEqual(
  TrackingCoordinates? left,
  TrackingCoordinates? right,
) {
  if (left == null || right == null) {
    return false;
  }

  final latitudeDelta = (left.latitude - right.latitude).abs();
  final longitudeDelta = (left.longitude - right.longitude).abs();
  return latitudeDelta < 0.0001 && longitudeDelta < 0.0001;
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

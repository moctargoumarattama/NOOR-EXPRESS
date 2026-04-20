import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/map/tile_cache_service.dart';
import '../../../../map/data/models/map_point.dart';
import '../../../../map/widgets/pulse_marker.dart';

class DriverMapView extends StatefulWidget {
  const DriverMapView({
    super.key,
    this.position,
  });

  final MapPoint? position;

  @override
  State<DriverMapView> createState() => DriverMapViewState();
}

class DriverMapViewState extends State<DriverMapView> {
  static const _niameyCenter = LatLng(13.5137, 2.1098);
  final MapController _controller = MapController();

  void recenter() {
    _controller.move(_point, 15);
  }

  @override
  void didUpdateWidget(covariant DriverMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) => recenter());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _point,
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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.noorexpress.app',
                tileProvider: createNoorTileProvider(),
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 78,
                    height: 78,
                    child: const PulseMarker(color: Color(0xFF1B8A5A)),
                  ),
                ],
              ),
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
    );
  }

  void _zoomBy(double delta) {
    _controller.move(
      _controller.camera.center,
      (_controller.camera.zoom + delta).clamp(10, 19),
    );
  }

  LatLng get _point {
    final position = widget.position;
    if (position == null) {
      return _niameyCenter;
    }
    return LatLng(position.latitude, position.longitude);
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

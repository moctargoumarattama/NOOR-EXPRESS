import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../models/route_result.dart';

class RoutingService {
  RoutingService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final Map<String, RouteResult> _cache = {};

  Future<RouteResult> getRoute(LatLng origin, LatLng destination) async {
    final key = _cacheKey(origin, destination);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/routing/route',
        queryParameters: {
          'origin_lat': origin.latitude,
          'origin_lng': origin.longitude,
          'dest_lat': destination.latitude,
          'dest_lng': destination.longitude,
        },
      );
      final payload = response.data;
      final route = payload == null
          ? RouteResult.fallback(origin, destination)
          : RouteResult.fromJson(payload);
      return _remember(key, route);
    } on DioException {
      return _remember(key, RouteResult.fallback(origin, destination));
    }
  }

  RouteResult _remember(String key, RouteResult route) {
    _cache[key] = route;
    while (_cache.length > 10) {
      _cache.remove(_cache.keys.first);
    }
    return route;
  }

  String _cacheKey(LatLng origin, LatLng destination) {
    String compact(LatLng point) {
      return '${point.latitude.toStringAsFixed(5)},'
          '${point.longitude.toStringAsFixed(5)}';
    }

    return '${compact(origin)}->${compact(destination)}';
  }
}

final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService(apiClient: ref.watch(apiClientProvider));
});

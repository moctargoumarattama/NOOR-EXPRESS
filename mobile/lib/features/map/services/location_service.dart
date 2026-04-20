import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart' as core_location;
import '../../../core/network/api_client.dart';

const niameyFallbackPosition = LatLng(13.5137, 2.1098);

class MapLocationService {
  MapLocationService({
    required core_location.LocationService locationService,
    required ApiClient apiClient,
  })  : _locationService = locationService,
        _apiClient = apiClient;

  final core_location.LocationService _locationService;
  final ApiClient _apiClient;

  Future<LatLng> getCurrentPosition() async {
    final result = await _locationService.getCurrentPosition(
      accuracy: LocationAccuracy.high,
      timeout: const Duration(seconds: 10),
    );
    if (result is core_location.LocationSuccess<Position>) {
      final position = result.value;
      return LatLng(position.latitude, position.longitude);
    }
    return niameyFallbackPosition;
  }

  Stream<LatLng> watchPosition() async* {
    var lastEmission = DateTime.fromMillisecondsSinceEpoch(0);
    await for (final result in _locationService.streamPosition(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    )) {
      if (result is! core_location.LocationSuccess<Position>) {
        continue;
      }
      final now = DateTime.now();
      if (now.difference(lastEmission) < const Duration(seconds: 3)) {
        continue;
      }
      lastEmission = now;
      final position = result.value;
      yield LatLng(position.latitude, position.longitude);
    }
  }

  Future<String> reverseGeocode(LatLng point) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/geocoding/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lng': point.longitude,
        },
      );
      return response.data?['display_name'] as String? ??
          'Position actuelle, Niamey';
    } on DioException {
      return 'Position actuelle, Niamey';
    }
  }
}

final mapLocationServiceProvider = Provider<MapLocationService>((ref) {
  return MapLocationService(
    locationService: ref.watch(core_location.locationServiceProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

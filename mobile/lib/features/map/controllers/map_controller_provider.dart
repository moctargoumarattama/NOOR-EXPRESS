import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';

class NoorMapState {
  const NoorMapState({
    this.currentPosition = niameyFallbackPosition,
    this.route,
    this.isLoadingRoute = false,
    this.errorMessage,
  });

  final LatLng currentPosition;
  final RouteResult? route;
  final bool isLoadingRoute;
  final String? errorMessage;

  NoorMapState copyWith({
    LatLng? currentPosition,
    RouteResult? route,
    bool? isLoadingRoute,
    String? errorMessage,
    bool clearRoute = false,
    bool clearError = false,
  }) {
    return NoorMapState(
      currentPosition: currentPosition ?? this.currentPosition,
      route: clearRoute ? null : route ?? this.route,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class NoorMapController extends StateNotifier<NoorMapState> {
  NoorMapController({
    required MapLocationService locationService,
    required RoutingService routingService,
  })  : _locationService = locationService,
        _routingService = routingService,
        super(const NoorMapState());

  final MapLocationService _locationService;
  final RoutingService _routingService;

  Future<void> loadCurrentPosition() async {
    final position = await _locationService.getCurrentPosition();
    state = state.copyWith(currentPosition: position, clearError: true);
  }

  Future<void> calculateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    state = state.copyWith(isLoadingRoute: true, clearError: true);
    try {
      final route = await _routingService.getRoute(origin, destination);
      state = state.copyWith(route: route, isLoadingRoute: false);
    } catch (_) {
      state = state.copyWith(
        route: RouteResult.fallback(origin, destination),
        isLoadingRoute: false,
        errorMessage: 'Trajet estime en ligne droite.',
      );
    }
  }

  void clearRoute() {
    state = state.copyWith(clearRoute: true, clearError: true);
  }
}

final noorMapControllerProvider =
    StateNotifierProvider.autoDispose<NoorMapController, NoorMapState>((ref) {
  return NoorMapController(
    locationService: ref.watch(mapLocationServiceProvider),
    routingService: ref.watch(routingServiceProvider),
  );
});

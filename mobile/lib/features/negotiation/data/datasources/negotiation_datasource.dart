import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/ride_offer_model.dart';

enum NegotiationSocketEventType {
  newOffer,
  offerAccepted,
  offerRejected,
  rideStatus,
}

class NegotiationSocketEvent {
  const NegotiationSocketEvent({
    required this.type,
    required this.rideId,
    this.offer,
    this.status,
  });

  final NegotiationSocketEventType type;
  final int rideId;
  final RideOfferModel? offer;
  final String? status;
}

class NegotiationFailure implements Exception {
  const NegotiationFailure(this.message);

  final String message;
}

class NegotiationDatasource {
  NegotiationDatasource({
    required ApiClient apiClient,
    required WebSocketService websocketService,
    required SecureStorageService storageService,
  })  : _apiClient = apiClient,
        _websocketService = websocketService,
        _storageService = storageService;

  final ApiClient _apiClient;
  final WebSocketService _websocketService;
  final SecureStorageService _storageService;
  final _eventsController =
      StreamController<NegotiationSocketEvent>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  Stream<NegotiationSocketEvent> get events => _eventsController.stream;
  Stream<WebSocketStatus> get statuses => _websocketService.statuses;

  Future<void> connectClient(int clientId) async {
    _bindSocketStream();
    await _websocketService.connect(
      await _buildAuthenticatedUrl('/ws/clients/$clientId'),
    );
  }

  Future<void> connectDriver(int driverId) async {
    _bindSocketStream();
    await _websocketService.connect(
      await _buildAuthenticatedUrl('/ws/drivers/$driverId'),
    );
  }

  Future<void> disconnect() => _websocketService.disconnect();

  Future<Map<String, dynamic>?> fetchActiveRide() async {
    final payload = await _getMap('/ride-requests/active');
    return payload.isEmpty ? null : payload;
  }

  Future<NegotiationRideModel> fetchClientRide(int rideId) async {
    final payload = await _getMap('/ride-requests/$rideId');
    return NegotiationRideModel.fromRideRequestJson(payload);
  }

  Future<NegotiationRideModel> fetchDriverCandidateRide(int rideId) async {
    try {
      final response =
          await _apiClient.dio.get<List<dynamic>>('/ride-requests/available');
      final rides = response.data ?? const [];
      final payload = rides.whereType<Map<String, dynamic>>().firstWhere(
            (item) => ((item['id'] as num?)?.toInt() ?? 0) == rideId,
            orElse: () => <String, dynamic>{},
          );
      if (payload.isEmpty) {
        throw const NegotiationFailure('Ride introuvable ou plus disponible.');
      }
      return NegotiationRideModel.fromRideRequestJson(payload);
    } on DioException catch (error) {
      throw NegotiationFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage:
              'Operation de negociation impossible pour le moment.',
        ),
      );
    }
  }

  Future<List<RideOfferModel>> fetchOffers(int rideId) async {
    final response =
        await _apiClient.dio.get<List<dynamic>>('/ride-offers/$rideId');
    final payload = response.data ?? const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(RideOfferModel.fromJson)
        .toList();
  }

  Future<RideOfferModel> createOffer({
    required int rideId,
    required double proposedPrice,
  }) async {
    final payload = await _postMap(
      '/ride-offers/',
      data: {
        'ride_request_id': rideId,
        'proposed_price': proposedPrice,
      },
    );
    return RideOfferModel.fromJson(payload);
  }

  Future<void> acceptOffer(int offerId) =>
      _postMap('/ride-offers/$offerId/accept');

  Future<void> rejectOffer(int offerId) =>
      _postMap('/ride-offers/$offerId/reject');

  Future<Map<String, dynamic>> getPriceEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/pricing/estimate',
        queryParameters: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw NegotiationFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage:
              'Operation de negociation impossible pour le moment.',
        ),
      );
    }
  }

  Future<void> cancelRide(
    int rideId, {
    String? reason,
  }) =>
      _postMap(
        '/ride-requests/$rideId/cancel',
        data: {
          'reason': _cleanReason(reason),
        },
      );

  String _cleanReason(String? reason) {
    final value = reason?.trim();
    if (value == null || value.isEmpty) {
      return 'Annulee par le client';
    }
    return value;
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _eventsController.close();
  }

  void _bindSocketStream() {
    _messageSubscription ??= _websocketService.messages.listen(_handleMessage);
  }

  Future<String> _buildAuthenticatedUrl(String path) async {
    final token = await _storageService.readToken();
    final uri = Uri.parse(AppConfig.buildWsUrl(path));
    return uri
        .replace(queryParameters: token == null ? null : {'token': token})
        .toString();
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    switch (type) {
      case 'new_offer':
        final offerJson = message['offer'];
        if (offerJson is! Map<String, dynamic>) {
          return;
        }
        _eventsController.add(
          NegotiationSocketEvent(
            type: NegotiationSocketEventType.newOffer,
            rideId: ((offerJson['ride_id'] ??
                        message['ride_id'] ??
                        message['ride_request_id']) as num?)
                    ?.toInt() ??
                0,
            offer: RideOfferModel.fromWebSocketJson(offerJson),
          ),
        );
        return;
      case 'offer_accepted':
        _eventsController.add(
          NegotiationSocketEvent(
            type: NegotiationSocketEventType.offerAccepted,
            rideId: ((message['ride_id'] ?? 0) as num).toInt(),
          ),
        );
        return;
      case 'offer_rejected':
        _eventsController.add(
          NegotiationSocketEvent(
            type: NegotiationSocketEventType.offerRejected,
            rideId: ((message['ride_id'] ?? 0) as num).toInt(),
          ),
        );
        return;
      case 'status_update':
        _eventsController.add(
          NegotiationSocketEvent(
            type: NegotiationSocketEventType.rideStatus,
            rideId: ((message['ride_request_id'] ?? message['ride_id']) as num?)
                    ?.toInt() ??
                0,
            status: message['status'] as String?,
          ),
        );
        return;
    }
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(path);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw NegotiationFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage:
              'Operation de negociation impossible pour le moment.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _postMap(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response =
          await _apiClient.dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw NegotiationFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage:
              'Operation de negociation impossible pour le moment.',
        ),
      );
    }
  }
}

final negotiationDatasourceProvider =
    Provider.family<NegotiationDatasource, String>((ref, scope) {
  final datasource = NegotiationDatasource(
    apiClient: ref.watch(apiClientProvider),
    websocketService: ref.watch(websocketProvider('negotiation-$scope')),
    storageService: ref.watch(secureStorageServiceProvider),
  );
  ref.onDispose(() {
    datasource.dispose();
  });
  return datasource;
});

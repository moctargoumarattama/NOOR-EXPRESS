import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/features/home/client/data/client_rides_repository.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/controllers/client_home_controller.dart';

void main() {
  group('ClientHomeController.loadRides', () {
    test('keeps accepted ride history out of activeRide when backend has none',
        () async {
      final controller = ClientHomeController(
        repository: _FakeClientRidesRepository(
          rides: [
            _ride(
              id: 14,
              status: 'accepted',
              pickupLocation: 'Plateau',
              createdAt: DateTime(2026, 4, 23, 10),
            ),
          ],
          activeRide: null,
        ),
      );

      await controller.loadRides();

      expect(controller.state.rides, hasLength(1));
      expect(controller.state.activeRide, isNull);
    });

    test('exposes the backend active ride separately from the ride history',
        () async {
      final activeRide = _ride(
        id: 25,
        status: 'accepted',
        pickupLocation: 'Hassan',
        createdAt: DateTime(2026, 4, 24, 9),
      );
      final controller = ClientHomeController(
        repository: _FakeClientRidesRepository(
          rides: [
            _ride(
              id: 12,
              status: 'completed',
              pickupLocation: 'Agdal',
              createdAt: DateTime(2026, 4, 20, 18),
            ),
          ],
          activeRide: activeRide,
        ),
      );

      await controller.loadRides();

      expect(controller.state.activeRide?.id, activeRide.id);
    });

    test('clears a stale activeRide when backend active ride is empty',
        () async {
      final previousActiveRide = _ride(
        id: 25,
        status: 'accepted',
        pickupLocation: 'Hassan',
        createdAt: DateTime(2026, 4, 24, 9),
      );
      final repository = _FakeClientRidesRepository(
        rides: [previousActiveRide],
        activeRide: previousActiveRide,
      );
      final controller = ClientHomeController(repository: repository);

      await controller.loadRides();
      expect(controller.state.activeRide?.id, previousActiveRide.id);

      repository.activeRide = null;

      await controller.resumeFromLifecycle();

      expect(controller.state.activeRide, isNull);
    });
  });

  group('ClientHomeController.createRide', () {
    test('stores the backend conflict code for active ride recovery', () async {
      final controller = ClientHomeController(
        repository: _FakeClientRidesRepository(
          rides: const [],
          activeRide: null,
          createRideFailure: const ClientRideFailure(
            'Vous avez deja une course en cours.',
            code: 'client_already_has_active_ride',
          ),
        ),
      );

      final success = await controller.createRide(
        const RideRequestCreateInput(
          pickupLocation: 'Plateau',
          dropoffLocation: 'Ocean',
          clientLatitude: 1,
          clientLongitude: 2,
          dropoffLatitude: 3,
          dropoffLongitude: 4,
          estimatedPrice: 1500,
        ),
      );

      expect(success, isFalse);
      expect(
        controller.state.createErrorCode,
        'client_already_has_active_ride',
      );
    });
  });
}

class _FakeClientRidesRepository extends ClientRidesRepository {
  _FakeClientRidesRepository({
    required this.rides,
    required this.activeRide,
    this.createRideFailure,
  }) : super(apiClient: ApiClient());

  final List<ClientRide> rides;
  ClientRide? activeRide;
  final ClientRideFailure? createRideFailure;

  @override
  Future<List<ClientRide>> fetchMyRides({
    int limit = 100,
    int offset = 0,
  }) async {
    return rides;
  }

  @override
  Future<ClientRide?> fetchActiveRide() async {
    return activeRide;
  }

  @override
  Future<ClientRide> createRide(RideRequestCreateInput input) async {
    if (createRideFailure != null) {
      throw createRideFailure!;
    }
    return _ride(
      id: 99,
      status: 'pending',
      pickupLocation: input.pickupLocation,
      createdAt: DateTime(2026, 4, 24, 12),
    ).copyWith(dropoffLocation: input.dropoffLocation);
  }
}

ClientRide _ride({
  required int id,
  required String status,
  required String pickupLocation,
  required DateTime createdAt,
}) {
  return ClientRide(
    id: id,
    pickupLocation: pickupLocation,
    dropoffLocation: 'Destination',
    status: status,
    estimatedPrice: 3200,
    createdAt: createdAt,
  );
}

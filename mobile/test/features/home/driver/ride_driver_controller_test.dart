import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/features/home/driver/data/driver_rides_repository.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_ride.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/controllers/ride_driver_controller.dart';

void main() {
  group('RideDriverController.resumeFromLifecycle', () {
    test('restores the active ride from backend truth', () async {
      final activeRide = _ride(id: 42, status: 'accepted');
      final repository = _FakeDriverRidesRepository(
        rides: [_ride(id: 7, status: 'completed')],
        activeRide: activeRide,
      );
      final controller = RideDriverController(repository: repository);

      await controller.resumeFromLifecycle();

      expect(controller.state.activeRide?.id, activeRide.id);
      expect(repository.fetchActiveRideCalls, 1);
    });

    test('clears stale active ride when backend has no active ride', () async {
      final staleRide = _ride(id: 42, status: 'accepted');
      final repository = _FakeDriverRidesRepository(
        rides: [staleRide],
        activeRide: staleRide,
      );
      final controller = RideDriverController(repository: repository);

      await controller.resumeFromLifecycle();
      expect(controller.state.activeRide?.id, staleRide.id);

      repository.activeRide = null;

      await controller.resumeFromLifecycle();

      expect(controller.state.activeRide, isNull);
    });
  });
}

class _FakeDriverRidesRepository extends DriverRidesRepository {
  _FakeDriverRidesRepository({
    required this.rides,
    required this.activeRide,
  }) : super(apiClient: ApiClient());

  final List<DriverRide> rides;
  DriverRide? activeRide;
  int fetchActiveRideCalls = 0;

  @override
  Future<List<DriverRide>> fetchAvailableRides() async {
    return const [];
  }

  @override
  Future<List<DriverRide>> fetchMyRides({
    int limit = 100,
    int offset = 0,
  }) async {
    return rides;
  }

  @override
  Future<DriverRide?> fetchActiveRide() async {
    fetchActiveRideCalls += 1;
    return activeRide;
  }
}

DriverRide _ride({
  required int id,
  required String status,
}) {
  return DriverRide(
    id: id,
    pickupLocation: 'Grand Marche',
    dropoffLocation: 'Aeroport',
    status: status,
    estimatedPrice: 2500,
    createdAt: DateTime(2026, 4, 24, 10),
  );
}

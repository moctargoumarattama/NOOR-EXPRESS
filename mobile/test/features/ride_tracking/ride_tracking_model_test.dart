import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';

void main() {
  test('RideTrackingModel parses tracking coordinates and status', () {
    final model = RideTrackingModel.fromJson(
      {
        'id': 42,
        'client_id': 7,
        'driver_id': 13,
        'pickup_location': 'Plateau',
        'dropoff_location': 'Aeroport',
        'pickup_latitude': 13.512,
        'pickup_longitude': 2.121,
        'dropoff_latitude': 13.485,
        'dropoff_longitude': 2.171,
        'estimated_price': 2500,
        'status': 'arrived',
        'created_at': '2026-04-18T10:00:00',
      },
    );

    expect(model.id, 42);
    expect(model.status, RideTrackingStatus.arrived);
    expect(model.pickupPosition?.latitude, 13.512);
    expect(model.dropoffPosition?.longitude, 2.171);
  });
}

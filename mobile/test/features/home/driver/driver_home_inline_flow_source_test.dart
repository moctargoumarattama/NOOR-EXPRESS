import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DriverHomeScreen uses quick sheet flow with full-screen fallback', () {
    final source = File(
      'lib/features/home/driver/presentation/screens/driver_home_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('RideRequestPopup(')));
    expect(source, contains('AppRoutes.driverOffer'));
    expect(source, contains('onQuickOffer'));
    expect(source, contains('onRideRequestTimedOut'));
  });
}

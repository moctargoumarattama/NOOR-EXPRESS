import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DriverHomeScreen keeps ride negotiation on the home sheet path', () {
    final source = File(
      'lib/features/home/driver/presentation/screens/driver_home_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('RideRequestPopup(')));
    expect(source, isNot(contains('AppRoutes.driverOffer')));
  });
}

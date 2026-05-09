import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/location/location_quality.dart';

void main() {
  group('locationQualityFromAccuracy', () {
    test('returns confirmed when accuracy is <= 50m', () {
      expect(locationQualityFromAccuracy(50), LocationQuality.confirmed);
      expect(locationQualityFromAccuracy(12.4), LocationQuality.confirmed);
    });

    test('returns approximate when accuracy is between 50m and 200m', () {
      expect(locationQualityFromAccuracy(50.1), LocationQuality.approximate);
      expect(locationQualityFromAccuracy(200), LocationQuality.approximate);
    });

    test('returns approximate when accuracy is above 200m', () {
      expect(locationQualityFromAccuracy(350), LocationQuality.approximate);
    });

    test('returns unknown when accuracy is missing or invalid', () {
      expect(locationQualityFromAccuracy(null), LocationQuality.unknown);
      expect(locationQualityFromAccuracy(0), LocationQuality.unknown);
      expect(locationQualityFromAccuracy(-1), LocationQuality.unknown);
      expect(locationQualityFromAccuracy(double.nan), LocationQuality.unknown);
    });
  });
}

import '../../data/models/driver_ride.dart';

DriverRide? driverPendingRide(List<DriverRide> rides, int? pendingRideId) {
  if (pendingRideId != null) {
    for (final ride in rides) {
      if (ride.id == pendingRideId) {
        return ride;
      }
    }
  }
  return rides.isEmpty ? null : rides.first;
}

DriverRide? driverActiveRide(List<DriverRide> rides) {
  for (final ride in rides) {
    if (ride.status == 'accepted' ||
        ride.status == 'arrived' ||
        ride.status == 'started') {
      return ride;
    }
  }
  return null;
}

int driverTodayRides(List<DriverRide> rides) {
  final now = DateTime.now();
  return rides.where((ride) {
    return ride.createdAt.year == now.year &&
        ride.createdAt.month == now.month &&
        ride.createdAt.day == now.day;
  }).length;
}

double driverTodayEarnings(List<DriverRide> rides) {
  final now = DateTime.now();
  return rides.where((ride) {
    return ride.status == 'completed' &&
        ride.createdAt.year == now.year &&
        ride.createdAt.month == now.month &&
        ride.createdAt.day == now.day;
  }).fold<double>(0, (sum, ride) {
    return sum +
        (ride.driverNetEarnings ?? ride.finalPrice ?? ride.estimatedPrice);
  });
}

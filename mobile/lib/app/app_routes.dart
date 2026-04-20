abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const roleSelect = '/role-select';
  static const addressSearch = '/address-search';
  static const profile = '/profile';
  static const help = '/help';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const rideDetailBase = '/ride-detail';
  static const clientHome = '/client/home';
  static const clientHistory = '/client/history';
  static const clientMap = '/client/map';
  static const clientNegotiationBase = '/client/negotiation';
  static const driverHome = '/driver/home';
  static const driverMap = '/driver/map';
  static const driverProfile = '/driver/profile';
  static const driverVehicle = '/driver/vehicle';
  static const driverStats = '/driver/stats';
  static const driverHistory = '/driver/history';
  static const driverOnboarding = '/driver/onboarding';
  static const driverOnboardingStatus = '/driver/onboarding/status';
  static const driverOfferBase = '/driver/offer';

  static String clientMapWithRide(int rideId) => '$clientMap?rideId=$rideId';
  static String clientNegotiation(int rideId) =>
      '$clientNegotiationBase/$rideId';
  static String addressSearchFor(String mode) => '$addressSearch?mode=$mode';
  static String driverMapWithRide(int rideId) => '$driverMap?rideId=$rideId';
  static String driverOffer(int rideId) => '$driverOfferBase/$rideId';
  static String rideDetail(int rideId) => '$rideDetailBase/$rideId';
}

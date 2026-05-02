import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PassengerOnboardingStore {
  Future<bool?> readCompletedFlag();

  Future<void> writeCompletedFlag(bool isCompleted);
}

class SharedPreferencesPassengerOnboardingStore
    implements PassengerOnboardingStore {
  const SharedPreferencesPassengerOnboardingStore();

  static const completedFlagKey = 'passenger_onboarding.completed';

  @override
  Future<bool?> readCompletedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completedFlagKey);
  }

  @override
  Future<void> writeCompletedFlag(bool isCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedFlagKey, isCompleted);
  }
}

class PassengerOnboardingService {
  const PassengerOnboardingService({
    PassengerOnboardingStore store =
        const SharedPreferencesPassengerOnboardingStore(),
  }) : _store = store;

  final PassengerOnboardingStore _store;

  Future<bool> isCompleted() async {
    final isCompleted = await _store.readCompletedFlag();
    return isCompleted ?? false;
  }

  Future<void> markCompleted() {
    return _store.writeCompletedFlag(true);
  }

  Future<void> reset() {
    return _store.writeCompletedFlag(false);
  }
}

final passengerOnboardingServiceProvider = Provider<PassengerOnboardingService>(
  (ref) => const PassengerOnboardingService(),
);

final passengerOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(passengerOnboardingServiceProvider);
  return service.isCompleted();
});

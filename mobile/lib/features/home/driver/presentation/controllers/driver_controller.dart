import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/driver_repository.dart';
import '../../data/models/driver_profile.dart';

class DriverState {
  const DriverState({
    this.profile,
    required this.isLoading,
    required this.isUpdatingAvailability,
    required this.isSavingProfile,
    required this.isSavingRadius,
    this.errorMessage,
  });

  const DriverState.initial()
      : this(
          isLoading: false,
          isUpdatingAvailability: false,
          isSavingProfile: false,
          isSavingRadius: false,
        );

  final DriverProfile? profile;
  final bool isLoading;
  final bool isUpdatingAvailability;
  final bool isSavingProfile;
  final bool isSavingRadius;
  final String? errorMessage;

  DriverState copyWith({
    DriverProfile? profile,
    bool? isLoading,
    bool? isUpdatingAvailability,
    bool? isSavingProfile,
    bool? isSavingRadius,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DriverState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isUpdatingAvailability:
          isUpdatingAvailability ?? this.isUpdatingAvailability,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      isSavingRadius: isSavingRadius ?? this.isSavingRadius,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DriverController extends StateNotifier<DriverState> {
  DriverController({required DriverRepository repository})
      : _repository = repository,
        super(const DriverState.initial());

  final DriverRepository _repository;

  Future<void> loadProfile() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final profile = await _repository.fetchProfile();
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        clearErrorMessage: true,
      );
    } on DriverFailure catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
    }
  }

  Future<String?> updateAvailability(bool isAvailable) async {
    final targetStatus = isAvailable ? 'online' : 'offline';
    return updateStatus(targetStatus);
  }

  Future<String?> updateStatus(String status) async {
    state = state.copyWith(
      isUpdatingAvailability: true,
      clearErrorMessage: true,
    );

    try {
      final profile = await _repository.updateStatus(status);
      state = state.copyWith(
        profile: profile,
        isUpdatingAvailability: false,
        clearErrorMessage: true,
      );
      return null;
    } on DriverFailure catch (error) {
      state = state.copyWith(
        isUpdatingAvailability: false,
        errorMessage: error.message,
      );
      return error.message;
    }
  }

  Future<String?> updateProfile(DriverProfileUpdateInput input) async {
    state = state.copyWith(
      isSavingProfile: true,
      clearErrorMessage: true,
    );

    try {
      final profile = await _repository.updateProfile(input);
      state = state.copyWith(
        profile: profile,
        isSavingProfile: false,
        clearErrorMessage: true,
      );
      return null;
    } on DriverFailure catch (error) {
      state = state.copyWith(
        isSavingProfile: false,
        errorMessage: error.message,
      );
      return error.message;
    }
  }

  Future<String?> updateMaxRadiusKm(int maxRadiusKm) async {
    state = state.copyWith(
      isSavingRadius: true,
      clearErrorMessage: true,
    );

    try {
      final profile = await _repository.updateMaxRadiusKm(maxRadiusKm);
      state = state.copyWith(
        profile: profile,
        isSavingRadius: false,
        clearErrorMessage: true,
      );
      return null;
    } on DriverFailure catch (error) {
      state = state.copyWith(
        isSavingRadius: false,
        errorMessage: error.message,
      );
      return error.message;
    }
  }
}

final driverProvider =
    StateNotifierProvider<DriverController, DriverState>((ref) {
  return DriverController(repository: ref.watch(driverRepositoryProvider));
});

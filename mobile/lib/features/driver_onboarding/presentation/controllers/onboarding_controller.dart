import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/driver_profile_datasource.dart';
import '../../data/models/driver_profile_model.dart';

class DriverOnboardingState {
  const DriverOnboardingState({
    this.step = 0,
    this.firstName = '',
    this.lastName = '',
    this.address = '',
    this.idCardPhoto,
    this.selfiePhoto,
    this.profile,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final int step;
  final String firstName;
  final String lastName;
  final String address;
  final String? idCardPhoto;
  final String? selfiePhoto;
  final DriverOnboardingProfileModel? profile;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  bool get hasPersonalInfo =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      address.trim().isNotEmpty;

  DriverOnboardingState copyWith({
    int? step,
    String? firstName,
    String? lastName,
    String? address,
    String? idCardPhoto,
    String? selfiePhoto,
    DriverOnboardingProfileModel? profile,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverOnboardingState(
      step: step ?? this.step,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      address: address ?? this.address,
      idCardPhoto: idCardPhoto ?? this.idCardPhoto,
      selfiePhoto: selfiePhoto ?? this.selfiePhoto,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DriverOnboardingController extends StateNotifier<DriverOnboardingState> {
  DriverOnboardingController({required DriverProfileDatasource datasource})
      : _datasource = datasource,
        super(const DriverOnboardingState());

  final DriverProfileDatasource _datasource;

  void setStep(int step) {
    state = state.copyWith(step: step.clamp(0, 3), clearError: true);
  }

  void setPersonalInfo({
    required String firstName,
    required String lastName,
    required String address,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      address: address,
      clearError: true,
    );
  }

  void setIdCardPhoto(String value) {
    state = state.copyWith(idCardPhoto: value, clearError: true);
  }

  void setSelfiePhoto(String value) {
    state = state.copyWith(selfiePhoto: value, clearError: true);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _datasource.fetchProfile();
      state = state.copyWith(
        profile: profile,
        firstName: profile?.firstName ?? state.firstName,
        lastName: profile?.lastName ?? state.lastName,
        address: profile?.address ?? state.address,
        idCardPhoto: profile?.idCardPhoto ?? state.idCardPhoto,
        selfiePhoto: profile?.selfiePhoto ?? state.selfiePhoto,
        isLoading: false,
      );
    } on DriverProfileFailure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  Future<DriverOnboardingProfileModel?> submit() async {
    if (!state.hasPersonalInfo ||
        state.idCardPhoto == null ||
        state.selfiePhoto == null) {
      state = state.copyWith(errorMessage: 'Completez toutes les etapes.');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final profile = await _datasource.submitProfile(
        DriverProfileSubmitInput(
          firstName: state.firstName.trim(),
          lastName: state.lastName.trim(),
          address: state.address.trim(),
          idCardPhoto: state.idCardPhoto!,
          selfiePhoto: state.selfiePhoto!,
        ),
      );
      state = state.copyWith(
        profile: profile,
        isSubmitting: false,
        step: 3,
      );
      return profile;
    } on DriverProfileFailure catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
      );
      return null;
    }
  }
}

final driverOnboardingControllerProvider = StateNotifierProvider.autoDispose<
    DriverOnboardingController, DriverOnboardingState>((ref) {
  return DriverOnboardingController(
    datasource: ref.watch(driverProfileDatasourceProvider),
  );
});

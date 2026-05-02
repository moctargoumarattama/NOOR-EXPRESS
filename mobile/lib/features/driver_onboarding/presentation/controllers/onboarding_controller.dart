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
    this.driverLicense = const DriverLegalDocumentInput(
      file: null,
      expiresAt: null,
    ),
    this.vehicleRegistration = const DriverLegalDocumentInput(
      file: null,
      expiresAt: null,
    ),
    this.vehicleInsurance = const DriverLegalDocumentInput(
      file: null,
      expiresAt: null,
    ),
    this.technicalInspection = const DriverLegalDocumentInput(
      file: null,
      expiresAt: null,
    ),
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
  final DriverLegalDocumentInput driverLicense;
  final DriverLegalDocumentInput vehicleRegistration;
  final DriverLegalDocumentInput vehicleInsurance;
  final DriverLegalDocumentInput technicalInspection;
  final DriverOnboardingProfileModel? profile;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  bool get hasPersonalInfo =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      address.trim().isNotEmpty;

  bool get hasLegalDocuments =>
      driverLicense.isComplete &&
      vehicleRegistration.isComplete &&
      vehicleInsurance.isComplete &&
      technicalInspection.isComplete;

  String? get legalDocumentsError {
    final documents = {
      DriverLegalDocumentType.driverLicense: driverLicense,
      DriverLegalDocumentType.vehicleRegistration: vehicleRegistration,
      DriverLegalDocumentType.vehicleInsurance: vehicleInsurance,
      DriverLegalDocumentType.technicalInspection: technicalInspection,
    };
    for (final entry in documents.entries) {
      final message = entry.value.validationMessage(entry.key.label);
      if (message != null) {
        return message;
      }
    }
    return null;
  }

  DriverOnboardingState copyWith({
    int? step,
    String? firstName,
    String? lastName,
    String? address,
    String? idCardPhoto,
    String? selfiePhoto,
    DriverLegalDocumentInput? driverLicense,
    DriverLegalDocumentInput? vehicleRegistration,
    DriverLegalDocumentInput? vehicleInsurance,
    DriverLegalDocumentInput? technicalInspection,
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
      driverLicense: driverLicense ?? this.driverLicense,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
      vehicleInsurance: vehicleInsurance ?? this.vehicleInsurance,
      technicalInspection: technicalInspection ?? this.technicalInspection,
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
    state = state.copyWith(step: step.clamp(0, 4), clearError: true);
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

  void setLegalDocumentFile(DriverLegalDocumentType type, String value) {
    _setLegalDocument(type, _documentFor(type).copyWith(file: value));
  }

  void setLegalDocumentExpiration(
      DriverLegalDocumentType type, DateTime value) {
    _setLegalDocument(type, _documentFor(type).copyWith(expiresAt: value));
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
        driverLicense: profile?.driverLicense ?? state.driverLicense,
        vehicleRegistration:
            profile?.vehicleRegistration ?? state.vehicleRegistration,
        vehicleInsurance: profile?.vehicleInsurance ?? state.vehicleInsurance,
        technicalInspection:
            profile?.technicalInspection ?? state.technicalInspection,
        isLoading: false,
      );
    } on DriverProfileFailure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  Future<DriverOnboardingProfileModel?> submit() async {
    final missingMessage = _missingSubmissionMessage();
    if (missingMessage != null) {
      state = state.copyWith(errorMessage: missingMessage);
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
          driverLicense: state.driverLicense,
          vehicleRegistration: state.vehicleRegistration,
          vehicleInsurance: state.vehicleInsurance,
          technicalInspection: state.technicalInspection,
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

  DriverLegalDocumentInput _documentFor(DriverLegalDocumentType type) {
    return switch (type) {
      DriverLegalDocumentType.driverLicense => state.driverLicense,
      DriverLegalDocumentType.vehicleRegistration => state.vehicleRegistration,
      DriverLegalDocumentType.vehicleInsurance => state.vehicleInsurance,
      DriverLegalDocumentType.technicalInspection => state.technicalInspection,
    };
  }

  void _setLegalDocument(
    DriverLegalDocumentType type,
    DriverLegalDocumentInput document,
  ) {
    state = switch (type) {
      DriverLegalDocumentType.driverLicense =>
        state.copyWith(driverLicense: document, clearError: true),
      DriverLegalDocumentType.vehicleRegistration =>
        state.copyWith(vehicleRegistration: document, clearError: true),
      DriverLegalDocumentType.vehicleInsurance =>
        state.copyWith(vehicleInsurance: document, clearError: true),
      DriverLegalDocumentType.technicalInspection =>
        state.copyWith(technicalInspection: document, clearError: true),
    };
  }

  String? _missingSubmissionMessage() {
    if (!state.hasPersonalInfo ||
        state.idCardPhoto == null ||
        state.selfiePhoto == null) {
      return 'Completez toutes les etapes.';
    }
    return state.legalDocumentsError;
  }
}

final driverOnboardingControllerProvider = StateNotifierProvider.autoDispose<
    DriverOnboardingController, DriverOnboardingState>((ref) {
  return DriverOnboardingController(
    datasource: ref.watch(driverProfileDatasourceProvider),
  );
});

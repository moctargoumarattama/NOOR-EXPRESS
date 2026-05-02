import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/photo_picker_types.dart';
import '../../data/datasources/profile_datasource.dart';
import '../../data/models/client_profile_model.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.rides = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  final ClientProfileModel? profile;
  final List<ClientProfileRideModel> rides;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  ProfileState copyWith({
    ClientProfileModel? profile,
    List<ClientProfileRideModel>? rides,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      rides: rides ?? this.rides,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController({required ProfileDatasource datasource})
      : _datasource = datasource,
        super(const ProfileState());

  final ProfileDatasource _datasource;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _datasource.fetchClientProfile();
      final rides = await _datasource.fetchRecentRides();
      state = state.copyWith(
        profile: profile,
        rides: rides,
        isLoading: false,
      );
    } on ProfileFailure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  Future<void> save({
    String? firstName,
    NoorPickedPhoto? profilePhoto,
    String successMessage = 'Profil mis a jour.',
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final profile = await _datasource.updateClientProfile(
        firstName: firstName,
        profilePhoto: profilePhoto,
      );
      state = state.copyWith(
        profile: profile,
        isSaving: false,
        successMessage: successMessage,
      );
    } on ProfileFailure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    }
  }

  void consumeMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, ProfileState>((ref) {
  return ProfileController(datasource: ref.watch(profileDatasourceProvider));
});

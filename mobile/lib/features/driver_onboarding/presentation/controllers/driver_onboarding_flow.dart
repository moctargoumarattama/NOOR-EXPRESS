import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/state/session_controller.dart';
import '../../data/datasources/driver_profile_datasource.dart';
import '../../data/models/driver_profile_model.dart';

enum DriverOnboardingFlowState {
  needsSubmission,
  pendingValidation,
  rejected,
  verified,
  unknown,
}

final driverOnboardingFlowProvider =
    FutureProvider<DriverOnboardingFlowState>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session.status != SessionStatus.authenticated ||
      session.role != AppRole.driver) {
    return DriverOnboardingFlowState.verified;
  }

  final datasource = ref.watch(driverProfileDatasourceProvider);
  try {
    final profile = await datasource.fetchProfile();
    if (profile == null) {
      return DriverOnboardingFlowState.needsSubmission;
    }
    return switch (profile.verificationStatus) {
      DriverVerificationStatus.pending =>
        DriverOnboardingFlowState.pendingValidation,
      DriverVerificationStatus.rejected => DriverOnboardingFlowState.rejected,
      DriverVerificationStatus.verified => DriverOnboardingFlowState.verified,
    };
  } on DriverProfileFailure {
    return DriverOnboardingFlowState.unknown;
  }
});

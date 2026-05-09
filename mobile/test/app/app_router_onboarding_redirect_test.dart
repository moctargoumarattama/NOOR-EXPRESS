import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/app/app_router.dart';
import 'package:noor_express_mobile/app/app_routes.dart';
import 'package:noor_express_mobile/core/models/app_role.dart';
import 'package:noor_express_mobile/core/state/session_controller.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/controllers/driver_onboarding_flow.dart';

void main() {
  test('premier lancement client redirige vers onboarding', () {
    const sessionState = SessionState(
      status: SessionStatus.authenticated,
      role: AppRole.client,
      userId: 11,
      token: 'token',
    );

    final redirect = resolveAppRedirect(
      sessionState: sessionState,
      onboardingCompletedState: const AsyncData(false),
      driverOnboardingFlowState:
          const AsyncData(DriverOnboardingFlowState.verified),
      location: AppRoutes.splash,
    );

    expect(redirect, AppRoutes.clientOnboarding);
  });

  test('deuxieme lancement client ne repasse pas par onboarding', () {
    const sessionState = SessionState(
      status: SessionStatus.authenticated,
      role: AppRole.client,
      userId: 11,
      token: 'token',
    );

    final redirect = resolveAppRedirect(
      sessionState: sessionState,
      onboardingCompletedState: const AsyncData(true),
      driverOnboardingFlowState:
          const AsyncData(DriverOnboardingFlowState.verified),
      location: AppRoutes.splash,
    );

    expect(redirect, AppRoutes.clientHome);
    expect(redirect, isNot(AppRoutes.clientOnboarding));
  });

  test('passager redirige vers home passager depuis route chauffeur', () {
    const sessionState = SessionState(
      status: SessionStatus.authenticated,
      role: AppRole.client,
      userId: 22,
      token: 'token',
    );

    final redirect = resolveAppRedirect(
      sessionState: sessionState,
      onboardingCompletedState: const AsyncData(true),
      driverOnboardingFlowState:
          const AsyncData(DriverOnboardingFlowState.verified),
      location: AppRoutes.driverHome,
    );

    expect(redirect, AppRoutes.clientHome);
  });

  test('chauffeur redirige vers home chauffeur depuis route passager', () {
    const sessionState = SessionState(
      status: SessionStatus.authenticated,
      role: AppRole.driver,
      userId: 33,
      token: 'token',
    );

    final redirect = resolveAppRedirect(
      sessionState: sessionState,
      onboardingCompletedState: const AsyncData(true),
      driverOnboardingFlowState:
          const AsyncData(DriverOnboardingFlowState.verified),
      location: AppRoutes.clientHome,
    );

    expect(redirect, AppRoutes.driverHome);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/app/app_router.dart';
import 'package:noor_express_mobile/app/app_routes.dart';
import 'package:noor_express_mobile/core/models/app_role.dart';
import 'package:noor_express_mobile/core/state/session_controller.dart';

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
      location: AppRoutes.splash,
    );

    expect(redirect, AppRoutes.clientHome);
    expect(redirect, isNot(AppRoutes.clientOnboarding));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/app_role.dart';
import '../core/services/passenger_onboarding_service.dart';
import '../core/state/session_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/role_select_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/address_search/presentation/screens/address_search_screen.dart';
import '../features/home/client/presentation/screens/client_history_screen.dart';
import '../features/home/client/presentation/screens/client_home_screen.dart';
import '../features/home/driver/presentation/screens/driver_history_screen.dart';
import '../features/home/driver/presentation/screens/driver_earnings_screen.dart';
import '../features/home/driver/presentation/screens/driver_home_screen.dart';
import '../features/home/driver/presentation/screens/driver_profile_screen.dart';
import '../features/home/driver/presentation/screens/driver_stats_screen.dart';
import '../features/home/driver/presentation/screens/driver_vehicle_screen.dart';
import '../features/driver_onboarding/presentation/screens/driver_onboarding_screen.dart';
import '../features/driver_onboarding/presentation/screens/driver_onboarding_status_screen.dart';
import '../features/driver_onboarding/presentation/controllers/driver_onboarding_flow.dart';
import '../features/history/screens/ride_detail_screen.dart';
import '../features/negotiation/presentation/screens/client_negotiation_screen.dart';
import '../features/negotiation/presentation/screens/driver_offer_screen.dart';
import '../features/onboarding/presentation/screens/passenger_onboarding_screen.dart';
import '../features/profile/presentation/screens/client_profile_screen.dart';
import '../features/ride_tracking/presentation/screens/client_tracking_screen.dart';
import '../features/ride_tracking/presentation/screens/driver_tracking_screen.dart';
import '../shared/screens/help_screen.dart';
import '../shared/screens/notifications_screen.dart';
import '../shared/screens/settings_screen.dart';
import '../shared/screens/support_screen.dart';
import '../shared/screens/usage_policy_screen.dart';
import 'app_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionState = ref.watch(sessionControllerProvider);
  final onboardingCompletedState = ref.watch(
    passengerOnboardingCompletedProvider,
  );
  final driverOnboardingFlowState = ref.watch(driverOnboardingFlowProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.otp,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const OtpScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const RoleSelectScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientHome,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const ClientHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientOnboarding,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const PassengerOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const ClientProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const HelpScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.support,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const SupportScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.usagePolicy,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const UsagePolicyScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.rideDetailBase}/:rideId',
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: RideDetailScreen(
            rideId: int.tryParse(state.pathParameters['rideId'] ?? '') ?? 0,
            initialData: state.extra is Map<String, dynamic>
                ? state.extra as Map<String, dynamic>
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientHistory,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const ClientHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.addressSearch,
        pageBuilder: (context, state) => _bottomSlidePage(
          key: state.pageKey,
          child: AddressSearchScreen(
            mode: state.uri.queryParameters['mode'] == 'pickup'
                ? AddressSearchMode.pickup
                : AddressSearchMode.dropoff,
          ),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.clientNegotiationBase}/:rideId',
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: ClientNegotiationScreen(
            rideId: int.tryParse(state.pathParameters['rideId'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientMap,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: ClientTrackingScreen(
            rideId: int.tryParse(state.uri.queryParameters['rideId'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverHome,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverEarnings,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverEarningsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverStats,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverStatsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverProfile,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverVehicle,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverVehicleScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverHistory,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverOnboarding,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverOnboardingStatus,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: const DriverOnboardingStatusScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.driverOfferBase}/:rideId',
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: DriverOfferScreen(
            rideId: int.tryParse(state.pathParameters['rideId'] ?? '') ?? 0,
            initialPayload: state.extra is Map<String, dynamic>
                ? state.extra as Map<String, dynamic>
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.driverMap,
        pageBuilder: (context, state) => _fastFadePage(
          key: state.pageKey,
          child: DriverTrackingScreen(
            rideId: int.tryParse(state.uri.queryParameters['rideId'] ?? ''),
          ),
        ),
      ),
    ],
    redirect: (context, state) {
      return resolveAppRedirect(
        sessionState: sessionState,
        onboardingCompletedState: onboardingCompletedState,
        driverOnboardingFlowState: driverOnboardingFlowState,
        location: state.matchedLocation,
      );
    },
  );
});

String? resolveAppRedirect({
  required SessionState sessionState,
  required AsyncValue<bool> onboardingCompletedState,
  required AsyncValue<DriverOnboardingFlowState> driverOnboardingFlowState,
  required String location,
}) {
  final isSplash = location == AppRoutes.splash;
  final isLogin = location == AppRoutes.login;
  final isAuthFlow = isLogin ||
      location == AppRoutes.register ||
      location == AppRoutes.otp ||
      location == AppRoutes.roleSelect;
  final isPassengerOnboarding = location == AppRoutes.clientOnboarding;
  final isDriverOnboarding = location == AppRoutes.driverOnboarding;
  final isDriverOnboardingStatus = location == AppRoutes.driverOnboardingStatus;

  switch (sessionState.status) {
    case SessionStatus.initial:
    case SessionStatus.loading:
      return isSplash ? null : AppRoutes.splash;
    case SessionStatus.restoreFailed:
      return isSplash ? null : AppRoutes.splash;
    case SessionStatus.unauthenticated:
      if (isPassengerOnboarding) {
        return AppRoutes.register;
      }
      return isAuthFlow ? null : AppRoutes.register;
    case SessionStatus.authenticated:
      final isClient = sessionState.role == AppRole.client;
      if (isClient) {
        if (onboardingCompletedState.isLoading) {
          return isSplash ? null : AppRoutes.splash;
        }
        final onboardingCompleted = onboardingCompletedState.valueOrNull;
        final mustShowOnboarding = onboardingCompleted != true;
        if (mustShowOnboarding && !isPassengerOnboarding) {
          return AppRoutes.clientOnboarding;
        }
        if (!mustShowOnboarding && isPassengerOnboarding) {
          return AppRoutes.clientHome;
        }
        if (_isDriverScopedLocation(location)) {
          return mustShowOnboarding
              ? AppRoutes.clientOnboarding
              : AppRoutes.clientHome;
        }
      } else if (isPassengerOnboarding) {
        return AppRoutes.driverHome;
      } else {
        if (driverOnboardingFlowState.isLoading) {
          if (isSplash || isDriverOnboarding || isDriverOnboardingStatus) {
            return null;
          }
          return AppRoutes.splash;
        }
        final driverFlow = driverOnboardingFlowState.valueOrNull ??
            DriverOnboardingFlowState.unknown;
        switch (driverFlow) {
          case DriverOnboardingFlowState.needsSubmission:
            return isDriverOnboarding ? null : AppRoutes.driverOnboarding;
          case DriverOnboardingFlowState.pendingValidation:
            return isDriverOnboardingStatus
                ? null
                : AppRoutes.driverOnboardingStatus;
          case DriverOnboardingFlowState.rejected:
            if (isDriverOnboarding || isDriverOnboardingStatus) {
              return null;
            }
            return isDriverOnboardingStatus
                ? null
                : AppRoutes.driverOnboardingStatus;
          case DriverOnboardingFlowState.verified:
            if (isDriverOnboarding || isDriverOnboardingStatus) {
              return AppRoutes.driverHome;
            }
            break;
          case DriverOnboardingFlowState.unknown:
            break;
        }
        if (_isClientScopedLocation(location)) {
          return AppRoutes.driverHome;
        }
      }

      final homeRoute = sessionState.role == AppRole.driver
          ? AppRoutes.driverHome
          : AppRoutes.clientHome;
      if (isSplash || isAuthFlow) {
        return homeRoute;
      }
      return null;
  }
}

bool _isDriverScopedLocation(String location) {
  return location.startsWith('/driver/');
}

bool _isClientScopedLocation(String location) {
  return location.startsWith('/client/');
}

CustomTransitionPage<void> _fastFadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<void> _bottomSlidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

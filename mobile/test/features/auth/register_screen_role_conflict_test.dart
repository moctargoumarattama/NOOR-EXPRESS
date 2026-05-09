import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noor_express_mobile/app/app_routes.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/features/auth/data/datasources/auth_datasource.dart';
import 'package:noor_express_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:noor_express_mobile/features/auth/presentation/screens/register_screen.dart';

void main() {
  const conflictMessage =
      'Ce numero est deja associe a un compte chauffeur. '
      'Connectez-vous avec votre compte existant ou utilisez un autre numero.';

  testWidgets('reponse 409 affiche un message clair et redirige vers login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2200));
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            return _FakeAuthController(
              ref: ref,
              conflictMessage: conflictMessage,
            );
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '90000000');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ce numero existe deja en tant que chauffeur. '
          'Voulez-vous vous connecter ?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('bouton utiliser un autre numero vide le champ telephone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2200));
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            return _FakeAuthController(
              ref: ref,
              conflictMessage: conflictMessage,
            );
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '90000000');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Utiliser un autre numero'));
    await tester.pumpAndSettle();

    final phoneField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(phoneField.controller?.text, isEmpty);
    await tester.binding.setSurfaceSize(null);
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.register,
    routes: [
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LOGIN_SCREEN'))),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('OTP_SCREEN'))),
      ),
    ],
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController({
    required super.ref,
    required this.conflictMessage,
  }) : super(
          datasource: _FakeAuthDatasource(),
        );

  final String conflictMessage;

  @override
  Future<bool> registerAndSendOtp({
    required String name,
    required String phoneNumber,
  }) async {
    state = state.copyWith(
      isLoading: false,
      errorMessage: conflictMessage,
    );
    return false;
  }
}

class _FakeAuthDatasource extends AuthDatasource {
  _FakeAuthDatasource() : super(apiClient: ApiClient());
}

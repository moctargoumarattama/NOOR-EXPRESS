import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/media/photo_picker_types.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:noor_express_mobile/features/profile/data/models/client_profile_model.dart';
import 'package:noor_express_mobile/features/profile/presentation/controllers/profile_controller.dart';
import 'package:noor_express_mobile/features/profile/presentation/screens/client_profile_screen.dart';

void main() {
  testWidgets(
    'Le bouton Enregistrer devient actif seulement apres une modification',
    (tester) async {
      final profile = ClientProfileModel(
        id: 10,
        name: 'Ali',
        phoneNumber: '+22790000000',
        profilePhoto: null,
        createdAt: DateTime(2026, 5, 2),
        totalRides: 12,
        averageRating: 4.7,
      );
      final controller = _FakeProfileController(
        ProfileState(
          profile: profile,
          rides: const [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: ClientProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Enregistrer');
      FilledButton saveButton = tester.widget<FilledButton>(saveButtonFinder);
      expect(saveButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Amadou');
      await tester.pump();

      saveButton = tester.widget<FilledButton>(saveButtonFinder);
      expect(saveButton.onPressed, isNotNull);
    },
  );

  testWidgets('Changer la photo ouvre les choix camera et galerie', (
    tester,
  ) async {
    final profile = ClientProfileModel(
      id: 11,
      name: 'Amina',
      phoneNumber: '+22791111111',
      profilePhoto: null,
      createdAt: DateTime(2026, 5, 2),
      totalRides: 7,
      averageRating: 4.5,
    );
    final controller = _FakeProfileController(
      ProfileState(
        profile: profile,
        rides: const [],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: ClientProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Changer la photo'));
    await tester.pumpAndSettle();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir depuis la galerie'), findsOneWidget);
  });
}

class _FakeProfileController extends ProfileController {
  _FakeProfileController(ProfileState initialState)
      : super(
          datasource: _FakeProfileDatasource(),
        ) {
    state = initialState;
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> save({
    String? firstName,
    NoorPickedPhoto? profilePhoto,
    String successMessage = 'Profil mis a jour.',
  }) async {
    final currentProfile = state.profile;
    if (currentProfile == null) {
      return;
    }
    state = state.copyWith(
      profile: ClientProfileModel(
        id: currentProfile.id,
        name: firstName ?? currentProfile.name,
        phoneNumber: currentProfile.phoneNumber,
        profilePhoto: currentProfile.profilePhoto,
        createdAt: currentProfile.createdAt,
        totalRides: currentProfile.totalRides,
        averageRating: currentProfile.averageRating,
      ),
      successMessage: successMessage,
    );
  }
}

class _FakeProfileDatasource extends ProfileDatasource {
  _FakeProfileDatasource()
      : super(
          apiClient: ApiClient(),
        );
}

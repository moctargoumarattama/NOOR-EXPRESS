import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/screens/step2_id_card_photo.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/screens/step3_selfie.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/screens/step4_confirmation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Step2IdCardPhoto uses simple identity copy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Step2IdCardPhoto(
            photo: null,
            onCamera: _noop,
            onGallery: _noop,
            onBack: _noop,
            onNext: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Votre piece d identite'), findsOneWidget);
    expect(find.text('Touchez ici pour prendre la photo'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Step3Selfie uses warm selfie guidance', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Step3Selfie(
            photo: null,
            onCamera: _noop,
            onGallery: _noop,
            onBack: _noop,
            onNext: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Votre selfie'), findsOneWidget);
    expect(find.text('Touchez pour prendre la photo'), findsOneWidget);
    expect(find.text('Prendre un selfie'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Step4Confirmation reassures before submission', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Step4Confirmation(
            fullName: 'Amina Noor',
            address: 'Niamey',
            idCardPhoto: null,
            selfiePhoto: null,
            isSubmitting: false,
            onBack: _noop,
            onSubmit: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Verifiez vos informations'), findsOneWidget);
    expect(
      find.text('Nous verifierons vos documents le plus vite possible.'),
      findsOneWidget,
    );
    expect(find.text('Envoyer'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}

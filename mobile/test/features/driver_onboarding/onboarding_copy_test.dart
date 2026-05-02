import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/driver_onboarding/data/models/driver_profile_model.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/screens/step2_id_card_photo.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/screens/step3_selfie.dart';
import 'package:noor_express_mobile/features/driver_onboarding/presentation/screens/step4_confirmation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DriverProfileSubmitInput serializes private driver documents', () {
    final input = DriverProfileSubmitInput(
      firstName: 'Amina',
      lastName: 'Noor',
      address: 'Niamey',
      idCardPhoto: 'id-card',
      selfiePhoto: 'selfie',
      driverLicense: _document('license', DateTime(2027, 1, 1)),
      vehicleRegistration: _document('registration', DateTime(2027, 1, 2)),
      vehicleInsurance: _document('insurance', DateTime(2027, 1, 3)),
      technicalInspection: _document('inspection', DateTime(2027, 1, 4)),
    );

    expect(input.isComplete, isTrue);
    expect(input.toJson()['driver_license_file'], 'license');
    expect(input.toJson()['technical_inspection_expires_at'], '2027-01-04');
  });

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

  testWidgets('StepLegalDocuments asks for private car legal documents',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepLegalDocuments(
            driverLicense: _document(null, null),
            vehicleRegistration: _document(null, null),
            vehicleInsurance: _document(null, null),
            technicalInspection: _document(null, null),
            onCamera: _noopDocument,
            onGallery: _noopDocument,
            onExpiryTap: _noopDocument,
            onBack: _noop,
            onNext: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Documents chauffeur prive'), findsOneWidget);
    expect(find.text('Permis de conduire'), findsOneWidget);
    expect(find.text('Carte grise du vehicule'), findsOneWidget);
    expect(find.text('Assurance auto'), findsOneWidget);
    expect(find.text('Visite technique'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Step4Confirmation reassures before submission', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Step4Confirmation(
            fullName: 'Amina Noor',
            address: 'Niamey',
            idCardPhoto: null,
            selfiePhoto: null,
            driverLicense: _document(null, null),
            vehicleRegistration: _document(null, null),
            vehicleInsurance: _document(null, null),
            technicalInspection: _document(null, null),
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

DriverLegalDocumentInput _document(String? file, DateTime? expiresAt) {
  return DriverLegalDocumentInput(file: file, expiresAt: expiresAt);
}

void _noop() {}

void _noopDocument(DriverLegalDocumentType type) {}

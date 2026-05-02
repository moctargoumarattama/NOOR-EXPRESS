import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/media/photo_picker_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/driver_profile_model.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_chrome.dart';
import 'step1_personal_info.dart';
import 'step2_id_card_photo.dart';
import 'step3_selfie.dart';
import 'step4_confirmation.dart';

const _maxDocumentExpiryYears = 10;

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() =>
      _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState
    extends ConsumerState<DriverOnboardingScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(driverOnboardingControllerProvider.notifier).load();
      if (!mounted) {
        return;
      }
      final state = ref.read(driverOnboardingControllerProvider);
      _firstNameController.text = state.firstName;
      _lastNameController.text = state.lastName;
      _addressController.text = state.address;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverOnboardingControllerProvider);
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            DriverOnboardingHeader(
              onBack: () => context.go(AppRoutes.driverHome),
            ),
            const SizedBox(height: 16),
            DriverOnboardingStepper(step: state.step),
            const SizedBox(height: 18),
            if (state.errorMessage != null) ...[
              DriverOnboardingErrorBox(message: state.errorMessage!),
              const SizedBox(height: 14),
            ],
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _currentStep(state, session.phoneNumber ?? ''),
              ),
          ],
        ),
      ),
    );
  }

  Widget _currentStep(DriverOnboardingState state, String phoneNumber) {
    return switch (state.step) {
      0 => Step1PersonalInfo(
          key: const ValueKey('step-1'),
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          addressController: _addressController,
          phoneNumber: phoneNumber,
          onNext: _savePersonalInfo,
        ),
      1 => Step2IdCardPhoto(
          key: const ValueKey('step-2'),
          photo: state.idCardPhoto,
          onCamera: () => _pickPhoto(
            source: NoorPhotoSource.camera,
            target: _PhotoTarget.idCard,
          ),
          onGallery: () => _pickPhoto(
            source: NoorPhotoSource.gallery,
            target: _PhotoTarget.idCard,
          ),
          onBack: () => _setStep(0),
          onNext: () => _setStep(2),
        ),
      2 => StepLegalDocuments(
          key: const ValueKey('step-3'),
          driverLicense: state.driverLicense,
          vehicleRegistration: state.vehicleRegistration,
          vehicleInsurance: state.vehicleInsurance,
          technicalInspection: state.technicalInspection,
          onCamera: (type) => _pickLegalDocument(
            source: NoorPhotoSource.camera,
            type: type,
          ),
          onGallery: (type) => _pickLegalDocument(
            source: NoorPhotoSource.gallery,
            type: type,
          ),
          onExpiryTap: _pickDocumentExpiry,
          onBack: () => _setStep(1),
          onNext: () => _setStep(3),
        ),
      3 => Step3Selfie(
          key: const ValueKey('step-4'),
          photo: state.selfiePhoto,
          onCamera: () => _pickPhoto(
            source: NoorPhotoSource.camera,
            target: _PhotoTarget.selfie,
            preferFrontCamera: true,
          ),
          onGallery: () => _pickPhoto(
            source: NoorPhotoSource.gallery,
            target: _PhotoTarget.selfie,
          ),
          onBack: () => _setStep(2),
          onNext: () => _setStep(4),
        ),
      _ => Step4Confirmation(
          key: const ValueKey('step-4'),
          fullName: '${state.firstName} ${state.lastName}',
          address: state.address,
          idCardPhoto: state.idCardPhoto,
          selfiePhoto: state.selfiePhoto,
          driverLicense: state.driverLicense,
          vehicleRegistration: state.vehicleRegistration,
          vehicleInsurance: state.vehicleInsurance,
          technicalInspection: state.technicalInspection,
          isSubmitting: state.isSubmitting,
          onBack: () => _setStep(3),
          onSubmit: _submit,
        ),
    };
  }

  void _savePersonalInfo() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final address = _addressController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || address.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Prenom, nom et adresse sont obligatoires.',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    ref.read(driverOnboardingControllerProvider.notifier).setPersonalInfo(
          firstName: firstName,
          lastName: lastName,
          address: address,
        );
    _setStep(1);
  }

  Future<void> _pickPhoto({
    required NoorPhotoSource source,
    required _PhotoTarget target,
    bool preferFrontCamera = false,
  }) async {
    try {
      final photo = await ref.read(noorPhotoPickerServiceProvider).pickPhoto(
            source: source,
            preferFrontCamera: preferFrontCamera,
            maxWidth: 800,
            imageQuality: 75,
          );
      if (photo == null) {
        return;
      }
      final encoded = base64Encode(photo.bytes);
      final controller = ref.read(driverOnboardingControllerProvider.notifier);
      _applyPickedPhoto(controller, target, encoded);
    } on NoorPhotoPickerFailure catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackbar.show(
        context,
        message: error.message,
        tone: AppSnackbarTone.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackbar.show(
        context,
        message: 'Photo impossible. Essayez la galerie si la camera bloque.',
        tone: AppSnackbarTone.error,
      );
    }
  }

  Future<void> _pickLegalDocument({
    required NoorPhotoSource source,
    required DriverLegalDocumentType type,
  }) {
    return _pickPhoto(source: source, target: _photoTargetFor(type));
  }

  Future<void> _pickDocumentExpiry(DriverLegalDocumentType type) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + _maxDocumentExpiryYears),
      initialDate: today,
    );
    if (picked == null) {
      return;
    }
    ref
        .read(driverOnboardingControllerProvider.notifier)
        .setLegalDocumentExpiration(type, picked);
  }

  void _applyPickedPhoto(
    DriverOnboardingController controller,
    _PhotoTarget target,
    String encoded,
  ) {
    switch (target) {
      case _PhotoTarget.idCard:
        controller.setIdCardPhoto(encoded);
      case _PhotoTarget.selfie:
        controller.setSelfiePhoto(encoded);
      case _PhotoTarget.driverLicense:
        controller.setLegalDocumentFile(
          DriverLegalDocumentType.driverLicense,
          encoded,
        );
      case _PhotoTarget.vehicleRegistration:
        controller.setLegalDocumentFile(
          DriverLegalDocumentType.vehicleRegistration,
          encoded,
        );
      case _PhotoTarget.vehicleInsurance:
        controller.setLegalDocumentFile(
          DriverLegalDocumentType.vehicleInsurance,
          encoded,
        );
      case _PhotoTarget.technicalInspection:
        controller.setLegalDocumentFile(
          DriverLegalDocumentType.technicalInspection,
          encoded,
        );
    }
  }

  Future<void> _submit() async {
    final profile =
        await ref.read(driverOnboardingControllerProvider.notifier).submit();
    if (!mounted || profile == null) {
      return;
    }
    context.go(AppRoutes.driverOnboardingStatus);
  }

  void _setStep(int step) {
    ref.read(driverOnboardingControllerProvider.notifier).setStep(step);
  }
}

enum _PhotoTarget {
  idCard,
  selfie,
  driverLicense,
  vehicleRegistration,
  vehicleInsurance,
  technicalInspection,
}

_PhotoTarget _photoTargetFor(DriverLegalDocumentType type) {
  return switch (type) {
    DriverLegalDocumentType.driverLicense => _PhotoTarget.driverLicense,
    DriverLegalDocumentType.vehicleRegistration =>
      _PhotoTarget.vehicleRegistration,
    DriverLegalDocumentType.vehicleInsurance => _PhotoTarget.vehicleInsurance,
    DriverLegalDocumentType.technicalInspection =>
      _PhotoTarget.technicalInspection,
  };
}

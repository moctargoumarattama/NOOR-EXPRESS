import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/driver_profile_model.dart';

class Step2IdCardPhoto extends StatelessWidget {
  const Step2IdCardPhoto({
    super.key,
    required this.photo,
    required this.onCamera,
    required this.onGallery,
    required this.onBack,
    required this.onNext,
  });

  final String? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _PhotoStepCard(
      title: 'Votre piece d identite',
      subtitle: 'Prenez une photo nette de votre piece d identite.',
      icon: Icons.badge_rounded,
      placeholderIcon: Icons.photo_camera_rounded,
      placeholderText: 'Touchez ici pour prendre la photo',
      photo: photo,
      checks: const ['Recto lisible', 'Bonne luminosite', 'Pas de reflet'],
      primaryLabel: 'Prendre une photo',
      secondaryLabel: 'Choisir dans la galerie',
      onCamera: onCamera,
      onGallery: onGallery,
      onBack: onBack,
      onNext: photo == null ? null : onNext,
    );
  }
}

class StepLegalDocuments extends StatelessWidget {
  const StepLegalDocuments({
    super.key,
    required this.driverLicense,
    required this.vehicleRegistration,
    required this.vehicleInsurance,
    required this.technicalInspection,
    required this.onCamera,
    required this.onGallery,
    required this.onExpiryTap,
    required this.onBack,
    required this.onNext,
  });

  final DriverLegalDocumentInput driverLicense;
  final DriverLegalDocumentInput vehicleRegistration;
  final DriverLegalDocumentInput vehicleInsurance;
  final DriverLegalDocumentInput technicalInspection;
  final void Function(DriverLegalDocumentType type) onCamera;
  final void Function(DriverLegalDocumentType type) onGallery;
  final void Function(DriverLegalDocumentType type) onExpiryTap;
  final VoidCallback onBack;
  final VoidCallback onNext;

  bool get _isComplete =>
      driverLicense.isComplete &&
      vehicleRegistration.isComplete &&
      vehicleInsurance.isComplete &&
      technicalInspection.isComplete;

  @override
  Widget build(BuildContext context) {
    return _OnboardingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
            title: 'Documents chauffeur prive',
            subtitle: 'Ajoutez les documents du vehicule personnel.',
            icon: Icons.folder_copy_rounded,
          ),
          const SizedBox(height: 16),
          _LegalDocumentTile(
            type: DriverLegalDocumentType.driverLicense,
            document: driverLicense,
            onCamera: onCamera,
            onGallery: onGallery,
            onExpiryTap: onExpiryTap,
          ),
          _LegalDocumentTile(
            type: DriverLegalDocumentType.vehicleRegistration,
            document: vehicleRegistration,
            onCamera: onCamera,
            onGallery: onGallery,
            onExpiryTap: onExpiryTap,
          ),
          _LegalDocumentTile(
            type: DriverLegalDocumentType.vehicleInsurance,
            document: vehicleInsurance,
            onCamera: onCamera,
            onGallery: onGallery,
            onExpiryTap: onExpiryTap,
          ),
          _LegalDocumentTile(
            type: DriverLegalDocumentType.technicalInspection,
            document: technicalInspection,
            onCamera: onCamera,
            onGallery: onGallery,
            onExpiryTap: onExpiryTap,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(label: 'Retour', onPressed: onBack),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Suivant',
                  onPressed: _isComplete ? onNext : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoStepCard extends StatelessWidget {
  const _PhotoStepCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.placeholderIcon,
    required this.placeholderText,
    required this.photo,
    required this.checks,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onCamera,
    required this.onGallery,
    required this.onBack,
    required this.onNext,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData placeholderIcon;
  final String placeholderText;
  final String? photo;
  final List<String> checks;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bytes = photo == null ? null : base64Decode(photo!);
    return _OnboardingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle(
            title: title,
            subtitle: subtitle,
            icon: icon,
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onCamera,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: bytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          placeholderIcon,
                          size: 42,
                          color: AppColors.emerald,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          placeholderText,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          ...checks.map((item) => _CheckItem(label: item)),
          const SizedBox(height: 18),
          AppButton(label: primaryLabel, onPressed: onCamera),
          const SizedBox(height: 10),
          AppButton.secondary(label: secondaryLabel, onPressed: onGallery),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child:
                      AppButton.secondary(label: 'Retour', onPressed: onBack)),
              const SizedBox(width: 12),
              Expanded(child: AppButton(label: 'Suivant', onPressed: onNext)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.mint,
          child: Icon(icon, color: AppColors.emerald),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.stone)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalDocumentTile extends StatelessWidget {
  const _LegalDocumentTile({
    required this.type,
    required this.document,
    required this.onCamera,
    required this.onGallery,
    required this.onExpiryTap,
  });

  final DriverLegalDocumentType type;
  final DriverLegalDocumentInput document;
  final void Function(DriverLegalDocumentType type) onCamera;
  final void Function(DriverLegalDocumentType type) onGallery;
  final void Function(DriverLegalDocumentType type) onExpiryTap;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes =
        document.hasFile ? base64Decode(document.file!) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
            children: [
              _DocumentPreview(bytes: bytes),
              const SizedBox(width: 12),
              Expanded(
                child: _DocumentActions(
                  type: type,
                  document: document,
                  onCamera: onCamera,
                  onGallery: onGallery,
                  onExpiryTap: onExpiryTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      width: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? const Icon(Icons.description_rounded, color: AppColors.emerald)
          : Image.memory(bytes!, fit: BoxFit.cover),
    );
  }
}

class _DocumentActions extends StatelessWidget {
  const _DocumentActions({
    required this.type,
    required this.document,
    required this.onCamera,
    required this.onGallery,
    required this.onExpiryTap,
  });

  final DriverLegalDocumentType type;
  final DriverLegalDocumentInput document;
  final void Function(DriverLegalDocumentType type) onCamera;
  final void Function(DriverLegalDocumentType type) onGallery;
  final void Function(DriverLegalDocumentType type) onExpiryTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onCamera(type),
          icon: const Icon(Icons.photo_camera_rounded),
          label: const Text('Photo'),
        ),
        OutlinedButton.icon(
          onPressed: () => onGallery(type),
          icon: const Icon(Icons.photo_library_rounded),
          label: const Text('Galerie'),
        ),
        OutlinedButton.icon(
          onPressed: () => onExpiryTap(type),
          icon: const Icon(Icons.event_rounded),
          label: Text(_expiryLabel(document.expiresAt)),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _expiryLabel(DateTime? value) {
  if (value == null) {
    return 'Expiration';
  }
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

enum DriverVerificationStatus {
  pending,
  verified,
  rejected,
}

extension DriverVerificationStatusX on DriverVerificationStatus {
  String get storageValue => name;

  static DriverVerificationStatus fromValue(String? value) {
    for (final status in DriverVerificationStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return DriverVerificationStatus.pending;
  }
}

enum DriverDocumentStatus {
  enAttente,
  valide,
  expire,
  rejete,
}

extension DriverDocumentStatusX on DriverDocumentStatus {
  String get storageValue {
    return switch (this) {
      DriverDocumentStatus.enAttente => 'en_attente',
      DriverDocumentStatus.valide => 'validé',
      DriverDocumentStatus.expire => 'expiré',
      DriverDocumentStatus.rejete => 'rejeté',
    };
  }

  static DriverDocumentStatus fromValue(String? value) {
    for (final status in DriverDocumentStatus.values) {
      if (status.storageValue == value) {
        return status;
      }
    }
    return DriverDocumentStatus.enAttente;
  }
}

enum DriverLegalDocumentType {
  driverLicense,
  vehicleRegistration,
  vehicleInsurance,
  technicalInspection,
}

extension DriverLegalDocumentTypeX on DriverLegalDocumentType {
  String get label {
    return switch (this) {
      DriverLegalDocumentType.driverLicense => 'Permis de conduire',
      DriverLegalDocumentType.vehicleRegistration => 'Carte grise du vehicule',
      DriverLegalDocumentType.vehicleInsurance => 'Assurance auto',
      DriverLegalDocumentType.technicalInspection => 'Visite technique',
    };
  }
}

class DriverLegalDocumentInput {
  const DriverLegalDocumentInput({
    required this.file,
    required this.expiresAt,
  });

  final String? file;
  final DateTime? expiresAt;

  bool get hasFile => file != null && file!.trim().isNotEmpty;
  bool get isComplete => hasFile && expiresAt != null;

  String? validationMessage(String label) {
    if (!hasFile) {
      return '$label est requis.';
    }
    if (expiresAt == null) {
      return 'La date d expiration de $label est requise.';
    }
    return null;
  }

  DriverLegalDocumentInput copyWith({
    String? file,
    DateTime? expiresAt,
  }) {
    return DriverLegalDocumentInput(
      file: file ?? this.file,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory DriverLegalDocumentInput.fromJson(
    Map<String, dynamic> json, {
    required String fileKey,
    required String expiresAtKey,
  }) {
    return DriverLegalDocumentInput(
      file: json[fileKey] as String?,
      expiresAt: DateTime.tryParse(json[expiresAtKey] as String? ?? ''),
    );
  }
}

class DriverOnboardingProfileModel {
  const DriverOnboardingProfileModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.address,
    this.idCardPhoto,
    this.selfiePhoto,
    required this.driverLicense,
    required this.driverLicenseStatus,
    required this.vehicleRegistration,
    required this.vehicleRegistrationStatus,
    required this.vehicleInsurance,
    required this.vehicleInsuranceStatus,
    required this.technicalInspection,
    required this.technicalInspectionStatus,
    required this.verificationStatus,
    this.rejectionReason,
    this.submittedAt,
    this.verifiedAt,
    this.documentExpiryAlerts = const [],
  });

  final int id;
  final int userId;
  final String firstName;
  final String lastName;
  final String? address;
  final String? idCardPhoto;
  final String? selfiePhoto;
  final DriverLegalDocumentInput driverLicense;
  final DriverDocumentStatus driverLicenseStatus;
  final DriverLegalDocumentInput vehicleRegistration;
  final DriverDocumentStatus vehicleRegistrationStatus;
  final DriverLegalDocumentInput vehicleInsurance;
  final DriverDocumentStatus vehicleInsuranceStatus;
  final DriverLegalDocumentInput technicalInspection;
  final DriverDocumentStatus technicalInspectionStatus;
  final DriverVerificationStatus verificationStatus;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final List<String> documentExpiryAlerts;

  String get fullName => '$firstName $lastName'.trim();

  factory DriverOnboardingProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverOnboardingProfileModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      address: json['address'] as String?,
      idCardPhoto: json['id_card_photo'] as String?,
      selfiePhoto: json['selfie_photo'] as String?,
      driverLicense: DriverLegalDocumentInput.fromJson(
        json,
        fileKey: 'driver_license_file',
        expiresAtKey: 'driver_license_expires_at',
      ),
      driverLicenseStatus: DriverDocumentStatusX.fromValue(
        json['driver_license_status'] as String?,
      ),
      vehicleRegistration: DriverLegalDocumentInput.fromJson(
        json,
        fileKey: 'vehicle_registration_file',
        expiresAtKey: 'vehicle_registration_expires_at',
      ),
      vehicleRegistrationStatus: DriverDocumentStatusX.fromValue(
        json['vehicle_registration_status'] as String?,
      ),
      vehicleInsurance: DriverLegalDocumentInput.fromJson(
        json,
        fileKey: 'vehicle_insurance_file',
        expiresAtKey: 'vehicle_insurance_expires_at',
      ),
      vehicleInsuranceStatus: DriverDocumentStatusX.fromValue(
        json['vehicle_insurance_status'] as String?,
      ),
      technicalInspection: DriverLegalDocumentInput.fromJson(
        json,
        fileKey: 'technical_inspection_file',
        expiresAtKey: 'technical_inspection_expires_at',
      ),
      technicalInspectionStatus: DriverDocumentStatusX.fromValue(
        json['technical_inspection_status'] as String?,
      ),
      verificationStatus: DriverVerificationStatusX.fromValue(
        json['verification_status'] as String?,
      ),
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? ''),
      documentExpiryAlerts:
          (json['document_expiry_alerts'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class DriverProfileSubmitInput {
  const DriverProfileSubmitInput({
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.idCardPhoto,
    required this.selfiePhoto,
    required this.vehiclePhoto,
    required this.driverLicense,
    required this.vehicleRegistration,
    required this.vehicleInsurance,
    required this.technicalInspection,
  });

  final String firstName;
  final String lastName;
  final String address;
  final String idCardPhoto;
  final String selfiePhoto;
  final String vehiclePhoto;
  final DriverLegalDocumentInput driverLicense;
  final DriverLegalDocumentInput vehicleRegistration;
  final DriverLegalDocumentInput vehicleInsurance;
  final DriverLegalDocumentInput technicalInspection;

  bool get isComplete {
    return driverLicense.isComplete &&
        vehicleRegistration.isComplete &&
        vehicleInsurance.isComplete &&
        technicalInspection.isComplete;
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'address': address,
      'id_card_photo': idCardPhoto,
      'selfie_photo': selfiePhoto,
      'vehicle_photo': vehiclePhoto,
      'driver_license_file': driverLicense.file,
      'driver_license_expires_at': _dateOnly(driverLicense.expiresAt),
      'vehicle_registration_file': vehicleRegistration.file,
      'vehicle_registration_expires_at': _dateOnly(
        vehicleRegistration.expiresAt,
      ),
      'vehicle_insurance_file': vehicleInsurance.file,
      'vehicle_insurance_expires_at': _dateOnly(vehicleInsurance.expiresAt),
      'technical_inspection_file': technicalInspection.file,
      'technical_inspection_expires_at': _dateOnly(
        technicalInspection.expiresAt,
      ),
    };
  }
}

String? _dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  return value.toIso8601String().split('T').first;
}

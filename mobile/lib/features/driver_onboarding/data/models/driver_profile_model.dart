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

class DriverOnboardingProfileModel {
  const DriverOnboardingProfileModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.address,
    this.idCardPhoto,
    this.selfiePhoto,
    required this.verificationStatus,
    this.rejectionReason,
    this.submittedAt,
    this.verifiedAt,
  });

  final int id;
  final int userId;
  final String firstName;
  final String lastName;
  final String? address;
  final String? idCardPhoto;
  final String? selfiePhoto;
  final DriverVerificationStatus verificationStatus;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

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
      verificationStatus: DriverVerificationStatusX.fromValue(
        json['verification_status'] as String?,
      ),
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? ''),
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
  });

  final String firstName;
  final String lastName;
  final String address;
  final String idCardPhoto;
  final String selfiePhoto;

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'address': address,
      'id_card_photo': idCardPhoto,
      'selfie_photo': selfiePhoto,
    };
  }
}

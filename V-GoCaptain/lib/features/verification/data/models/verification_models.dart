import 'package:equatable/equatable.dart';

enum VerificationStatus {
  pendingDocuments,
  underReview,
  approved,
  rejected,
  suspended,
}

extension VerificationStatusX on VerificationStatus {
  String get label => switch (this) {
    VerificationStatus.pendingDocuments => 'قيد رفع المستندات',
    VerificationStatus.underReview => 'قيد المراجعة',
    VerificationStatus.approved => 'مقبول',
    VerificationStatus.rejected => 'مرفوض',
    VerificationStatus.suspended => 'موقوف',
  };

  static VerificationStatus parse(String? value) {
    return switch (value) {
      'UnderReview' => VerificationStatus.underReview,
      'Approved' => VerificationStatus.approved,
      'Rejected' => VerificationStatus.rejected,
      'Suspended' => VerificationStatus.suspended,
      _ => VerificationStatus.pendingDocuments,
    };
  }
}

enum DriverDocumentType {
  selfie,
  nationalIdFront,
  nationalIdBack,
  driverLicense,
  vehicleLicense,
}

extension DriverDocumentTypeX on DriverDocumentType {
  String get apiValue => switch (this) {
    DriverDocumentType.selfie => 'Selfie',
    DriverDocumentType.nationalIdFront => 'NationalIdFront',
    DriverDocumentType.nationalIdBack => 'NationalIdBack',
    DriverDocumentType.driverLicense => 'DriverLicense',
    DriverDocumentType.vehicleLicense => 'VehicleLicense',
  };

  String get label => switch (this) {
    DriverDocumentType.selfie => 'الصورة الشخصية',
    DriverDocumentType.nationalIdFront => 'البطاقة — وش',
    DriverDocumentType.nationalIdBack => 'البطاقة — ظهر',
    DriverDocumentType.driverLicense => 'رخصة القيادة',
    DriverDocumentType.vehicleLicense => 'رخصة العربية',
  };

  bool get requiresExpiry =>
      this == DriverDocumentType.driverLicense ||
      this == DriverDocumentType.vehicleLicense;

  static DriverDocumentType parse(String value) {
    return DriverDocumentType.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => DriverDocumentType.selfie,
    );
  }
}

enum DriverDocumentStatus { pending, approved, rejected }

extension DriverDocumentStatusX on DriverDocumentStatus {
  String get label => switch (this) {
    DriverDocumentStatus.pending => 'قيد المراجعة',
    DriverDocumentStatus.approved => 'مقبول',
    DriverDocumentStatus.rejected => 'مرفوض',
  };

  static DriverDocumentStatus parse(String? value) {
    return switch (value) {
      'Approved' => DriverDocumentStatus.approved,
      'Rejected' => DriverDocumentStatus.rejected,
      _ => DriverDocumentStatus.pending,
    };
  }
}

class DriverDocument extends Equatable {
  const DriverDocument({
    required this.id,
    required this.type,
    required this.status,
    this.expiryDate,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
    this.publicUrl,
  });

  final String id;
  final DriverDocumentType type;
  final DriverDocumentStatus status;
  final DateTime? expiryDate;
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;
  final String? publicUrl;

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id']?.toString() ?? '',
      type: DriverDocumentTypeX.parse(json['type']?.toString() ?? ''),
      status: DriverDocumentStatusX.parse(json['status']?.toString()),
      expiryDate: DateTime.tryParse(json['expiryDate']?.toString() ?? ''),
      rejectionReason: json['rejectionReason']?.toString(),
      uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewedAt']?.toString() ?? ''),
      publicUrl: json['publicUrl']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    status,
    expiryDate,
    rejectionReason,
    uploadedAt,
    reviewedAt,
    publicUrl,
  ];
}

class DriverVerification extends Equatable {
  const DriverVerification({
    required this.status,
    required this.documents,
    required this.requiredTypes,
    required this.missingTypes,
    required this.canGoOnline,
    this.name,
    this.phone,
    this.profilePicture,
    this.note,
    this.documentsDeadline,
    this.blockCode,
    this.blockMessage,
  });

  final VerificationStatus status;
  final List<DriverDocument> documents;
  final List<DriverDocumentType> requiredTypes;
  final List<DriverDocumentType> missingTypes;
  final bool canGoOnline;
  final String? name;
  final String? phone;
  final String? profilePicture;
  final String? note;
  final DateTime? documentsDeadline;
  final String? blockCode;
  final String? blockMessage;

  factory DriverVerification.fromJson(Map<String, dynamic> json) {
    final docs = json['documents'] is List
        ? json['documents'] as List
        : const [];
    final required = json['requiredTypes'] is List
        ? json['requiredTypes'] as List
        : const [];
    final missing = json['missingTypes'] is List
        ? json['missingTypes'] as List
        : const [];
    return DriverVerification(
      status: VerificationStatusX.parse(json['status']?.toString()),
      documents: docs
          .whereType<Map>()
          .map((e) => DriverDocument.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      requiredTypes: required
          .map((e) => DriverDocumentTypeX.parse(e.toString()))
          .toList(),
      missingTypes: missing
          .map((e) => DriverDocumentTypeX.parse(e.toString()))
          .toList(),
      canGoOnline: json['canGoOnline'] == true,
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      profilePicture: json['profilePicture']?.toString(),
      note: json['note']?.toString(),
      documentsDeadline: DateTime.tryParse(
        json['documentsDeadline']?.toString() ?? '',
      ),
      blockCode: json['blockCode']?.toString(),
      blockMessage: json['blockMessage']?.toString(),
    );
  }

  DriverDocument? documentFor(DriverDocumentType type) {
    for (final document in documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    status,
    documents,
    requiredTypes,
    missingTypes,
    canGoOnline,
    name,
    phone,
    profilePicture,
    note,
    documentsDeadline,
    blockCode,
    blockMessage,
  ];
}

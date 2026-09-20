class SavedCardModel {
  final int id;
  final String maskedPan;
  final DateTime? createdAt;

  SavedCardModel({
    required this.id,
    required this.maskedPan,
    this.createdAt,
  });

  factory SavedCardModel.fromJson(Map<String, dynamic> json) {
    return SavedCardModel(
      id: (json['id'] ?? json['Id']) as int,
      maskedPan: (json['maskedPan'] ?? json['MaskedPan'] ?? '').toString(),
      createdAt: DateTime.tryParse(
          (json['createdAt'] ?? json['CreatedAt'] ?? '').toString()),
    );
  }
}

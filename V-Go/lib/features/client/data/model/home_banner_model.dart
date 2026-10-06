/// An ad slot in the home carousel, managed from the dashboard.
class HomeBannerModel {
  const HomeBannerModel({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
  });

  final int id;
  final String imageUrl;

  /// Opened in the external browser on tap; null = image only.
  final String? linkUrl;

  factory HomeBannerModel.fromJson(Map<String, dynamic> json) =>
      HomeBannerModel(
        id: ((json['id'] ?? json['Id']) as num?)?.toInt() ?? 0,
        imageUrl: (json['imageUrl'] ?? json['ImageUrl'] ?? '').toString(),
        linkUrl: (json['linkUrl'] ?? json['LinkUrl'])?.toString(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageUrl': imageUrl,
    'linkUrl': linkUrl,
  };
}

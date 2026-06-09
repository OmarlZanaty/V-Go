/// A single rating left for the driver, from `Rate/userRates/{id}` (UserRateDTO).
class RatingModel {
  final int score;
  final String? comment;

  const RatingModel({required this.score, this.comment});

  factory RatingModel.fromJson(Map<String, dynamic> j) {
    return RatingModel(
      score: j['score'] is num
          ? (j['score'] as num).toInt()
          : int.tryParse('${j['score'] ?? 0}') ?? 0,
      comment: (j['comment'] as String?)?.trim().isEmpty ?? true
          ? null
          : j['comment'].toString(),
    );
  }
}

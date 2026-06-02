class SendRatingModel {
  final int score;
  final String tripId;
  final String fromUserId;
  final String toUserId;

  SendRatingModel({
    required this.score,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
  });
  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'tripId': tripId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
    };
  }
}

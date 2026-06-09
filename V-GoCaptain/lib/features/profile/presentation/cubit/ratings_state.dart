part of 'ratings_cubit.dart';

enum RatingsStatus { initial, loading, loaded, error }

class RatingsState extends Equatable {
  final RatingsStatus status;
  final List<RatingModel> ratings;
  final String? error;

  const RatingsState({
    this.status = RatingsStatus.initial,
    this.ratings = const [],
    this.error,
  });

  /// Average score across all ratings (0 when none).
  double get average => ratings.isEmpty
      ? 0
      : ratings.fold(0, (sum, r) => sum + r.score) / ratings.length;

  int get count => ratings.length;

  /// Ratings that include a written comment.
  List<RatingModel> get withComments =>
      ratings.where((r) => (r.comment ?? '').isNotEmpty).toList();

  RatingsState copyWith({
    RatingsStatus? status,
    List<RatingModel>? ratings,
    String? error,
    bool clearError = false,
  }) {
    return RatingsState(
      status: status ?? this.status,
      ratings: ratings ?? this.ratings,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, ratings, error];
}

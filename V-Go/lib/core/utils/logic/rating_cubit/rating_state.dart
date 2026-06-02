part of 'rating_cubit.dart';

enum RatingStatus {
  initial,
  connecting,
  connected,
  error,
  sendRatingLoading,
  sendRatingSuccess,
  sendRatingFailure,
  recieveRating,
}

extension RatingStatusExtension on RatingStatus {
  bool get isInitial => this == RatingStatus.initial;
  bool get isSendRatingLoading => this == RatingStatus.sendRatingLoading;
  bool get isSendRatingSuccess => this == RatingStatus.sendRatingSuccess;
  bool get isSendRatingFailure => this == RatingStatus.sendRatingFailure;
  bool get isRecieveRating => this == RatingStatus.recieveRating;
}

class RatingState extends Equatable {
  final RatingStatus status;
  final String errMessage;
  const RatingState({this.status = RatingStatus.initial, this.errMessage = ''});

  RatingState copyWith({RatingStatus? status, String? errMessage}) {
    return RatingState(
      status: status ?? this.status,
      errMessage: errMessage ?? this.errMessage,
    );
  }

  @override
  List<Object> get props => [status, errMessage];
}

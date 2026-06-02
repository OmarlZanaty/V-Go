import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../errors/exception.dart';
import '../../../services/rating_service.dart';
import '../../model/send_rating_model.dart';

part 'rating_state.dart';

class RatingCubit extends Cubit<RatingState> {
  RatingCubit(this._ratingService) : super(const RatingState());
  final RatingService _ratingService;

  Future<void> connect() async {
    emit(state.copyWith(status: RatingStatus.connecting));
    try {
      await _ratingService.connect();
      emit(state.copyWith(status: RatingStatus.connected));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RatingStatus.error,
          errMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  Future<void> sendRating(SendRatingModel ratingModel) async {
    emit(state.copyWith(status: RatingStatus.sendRatingLoading));
    try {
      await _ratingService.sendRating(ratingModel);
      emit(state.copyWith(status: RatingStatus.sendRatingSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RatingStatus.sendRatingFailure,
          errMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _ratingService.dispose();
    return super.close();
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception.dart';
import '../../data/models/rating_model.dart';
import '../../data/repo/profile_repo.dart';

part 'ratings_state.dart';

class RatingsCubit extends Cubit<RatingsState> {
  final ProfileRepo _repo;
  RatingsCubit(this._repo) : super(const RatingsState());

  Future<void> load() async {
    emit(state.copyWith(status: RatingsStatus.loading, clearError: true));
    try {
      final ratings = await _repo.getMyRatings();
      emit(state.copyWith(status: RatingsStatus.loaded, ratings: ratings));
    } catch (e) {
      emit(state.copyWith(
        status: RatingsStatus.error,
        error: ServerFailure.fromError(e).errMessage,
      ));
    }
  }
}

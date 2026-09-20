import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../errors/exception.dart';
import '../../model/payment_response_model.dart';
import '../../model/saved_card_model.dart';
import '../../repo/payment_repo/payment_repo.dart';

part 'saved_cards_state.dart';

class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit(this._repo) : super(const SavedCardsState());

  final PaymentRepo _repo;

  Future<void> load() async {
    emit(state.copyWith(status: SavedCardsStatus.loading));
    try {
      final cards = await _repo.getSavedCards();
      if (isClosed) return;
      emit(state.copyWith(status: SavedCardsStatus.loaded, cards: cards));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: SavedCardsStatus.error,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// Starts the add-card verification checkout; returns the checkout payload for
  /// the caller to open the webview, or null on failure (error emitted).
  Future<PaymentResponseModel?> requestAddCard() async {
    try {
      return await _repo.addCard();
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(
        status: SavedCardsStatus.error,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
      return null;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repo.deleteSavedCard(id);
      if (isClosed) return;
      emit(state.copyWith(
        cards: state.cards.where((c) => c.id != id).toList(),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: SavedCardsStatus.error,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }
}

part of 'saved_cards_cubit.dart';

enum SavedCardsStatus { initial, loading, loaded, error }

class SavedCardsState {
  final SavedCardsStatus status;
  final List<SavedCardModel> cards;
  final String errorMessage;

  const SavedCardsState({
    this.status = SavedCardsStatus.initial,
    this.cards = const [],
    this.errorMessage = '',
  });

  SavedCardsState copyWith({
    SavedCardsStatus? status,
    List<SavedCardModel>? cards,
    String? errorMessage,
  }) {
    return SavedCardsState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

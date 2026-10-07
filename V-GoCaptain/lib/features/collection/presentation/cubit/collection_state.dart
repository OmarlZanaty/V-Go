part of 'collection_cubit.dart';

class CollectionState extends Equatable {
  const CollectionState({
    this.data,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.success,
  });

  final MyCollection? data;
  final bool loading;
  final bool submitting;
  final String? error;
  final String? success;

  CollectionState copyWith({
    MyCollection? data,
    bool? loading,
    bool? submitting,
    String? error,
    String? success,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CollectionState(
      data: data ?? this.data,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }

  @override
  List<Object?> get props => [data, loading, submitting, error, success];
}

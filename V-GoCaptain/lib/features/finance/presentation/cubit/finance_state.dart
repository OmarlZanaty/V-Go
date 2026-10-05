part of 'finance_cubit.dart';

enum FinanceStatus { initial, loading, loaded, loadingMore, error }

class FinanceState extends Equatable {
  const FinanceState({
    this.summaryStatus = FinanceStatus.initial,
    this.ledgerStatus = FinanceStatus.initial,
    this.summary,
    this.ledger = const [],
    this.pageNumber = 0,
    this.hasNextPage = true,
    this.range = FinanceRange.week,
    this.isRefreshing = false,
    this.isSavingPayout = false,
    this.isSettling = false,
    this.error,
    this.success,
  });

  final FinanceStatus summaryStatus;
  final FinanceStatus ledgerStatus;
  final FinanceSummary? summary;
  final List<FinanceLedgerEntry> ledger;
  final int pageNumber;
  final bool hasNextPage;
  final FinanceRange range;
  final bool isRefreshing;
  final bool isSavingPayout;
  final bool isSettling;
  final String? error;
  final String? success;

  FinanceState copyWith({
    FinanceStatus? summaryStatus,
    FinanceStatus? ledgerStatus,
    FinanceSummary? summary,
    List<FinanceLedgerEntry>? ledger,
    int? pageNumber,
    bool? hasNextPage,
    FinanceRange? range,
    bool? isRefreshing,
    bool? isSavingPayout,
    bool? isSettling,
    String? error,
    bool clearError = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return FinanceState(
      summaryStatus: summaryStatus ?? this.summaryStatus,
      ledgerStatus: ledgerStatus ?? this.ledgerStatus,
      summary: summary ?? this.summary,
      ledger: ledger ?? this.ledger,
      pageNumber: pageNumber ?? this.pageNumber,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      range: range ?? this.range,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSavingPayout: isSavingPayout ?? this.isSavingPayout,
      isSettling: isSettling ?? this.isSettling,
      error: clearError ? null : error,
      success: clearSuccess ? null : success,
    );
  }

  @override
  List<Object?> get props => [
    summaryStatus,
    ledgerStatus,
    summary,
    ledger,
    pageNumber,
    hasNextPage,
    range,
    isRefreshing,
    isSavingPayout,
    isSettling,
    error,
    success,
  ];
}

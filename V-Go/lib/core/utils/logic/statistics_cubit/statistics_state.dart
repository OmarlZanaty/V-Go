part of 'statistics_cubit.dart';

enum StatisticsStatus {
  initial,
  getStatisticsSuccess,
  getStatisticsFailure,
  getStatisticsLoading,
  addExpenseSuccess,
  addExpenseFailure,
  addExpenseLoading,
  deleteExpenseSuccess,
  deleteExpenseFailure,
  deleteExpenseLoading,
  getAllExpensesSuccess,
  getAllExpensesFailure,
  getAllExpensesLoading,
}

extension StatisticsStatusExtension on StatisticsStatus {
  bool get isInitial => this == StatisticsStatus.initial;
  bool get isGetStatisticsSuccess =>
      this == StatisticsStatus.getStatisticsSuccess;
  bool get isGetStatisticsFailure =>
      this == StatisticsStatus.getStatisticsFailure;
  bool get isGetStatisticsLoading =>
      this == StatisticsStatus.getStatisticsLoading;
  bool get isAddExpenseSuccess => this == StatisticsStatus.addExpenseSuccess;
  bool get isAddExpenseFailure => this == StatisticsStatus.addExpenseFailure;
  bool get isAddExpenseLoading => this == StatisticsStatus.addExpenseLoading;
  bool get isDeleteExpenseSuccess =>
      this == StatisticsStatus.deleteExpenseSuccess;
  bool get isDeleteExpenseFailure =>
      this == StatisticsStatus.deleteExpenseFailure;
  bool get isDeleteExpenseLoading =>
      this == StatisticsStatus.deleteExpenseLoading;
  bool get isGetAllExpensesSuccess =>
      this == StatisticsStatus.getAllExpensesSuccess;
  bool get isGetAllExpensesFailure =>
      this == StatisticsStatus.getAllExpensesFailure;
  bool get isGetAllExpensesLoading =>
      this == StatisticsStatus.getAllExpensesLoading;
}

class StatisticsState extends Equatable {
  final StatisticsStatus status;
  final AdminStatisticsModel? adminStatistics;
  final AccountantStatisticsModel? accountantStatistics;
  final PeriodData? currentPeriodData;
  final AllExpensesResponseModel? allExpensesResponse;
  final String errorMessage;
  final String successMessage;

  const StatisticsState({
    this.status = StatisticsStatus.initial,
    this.accountantStatistics,
    this.adminStatistics,
    this.currentPeriodData,
    this.errorMessage = '',
    this.successMessage = '',
    this.allExpensesResponse,
  });

  StatisticsState copyWith({
    StatisticsStatus? status,
    AdminStatisticsModel? adminStatistics,
    AccountantStatisticsModel? accountantStatistics,
    PeriodData? currentPeriodData,
    String? errorMessage,
    AllExpensesResponseModel? allExpensesResponse,
    String? successMessage,
  }) {
    return StatisticsState(
      status: status ?? this.status,
      adminStatistics: adminStatistics ?? this.adminStatistics,
      accountantStatistics: accountantStatistics ?? this.accountantStatistics,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPeriodData: currentPeriodData ?? this.currentPeriodData,
      successMessage: successMessage ?? this.successMessage,
      allExpensesResponse: allExpensesResponse ?? this.allExpensesResponse,
    );
  }

  @override
  List<Object?> get props => [
    status,
    accountantStatistics,
    adminStatistics,
    errorMessage,
    currentPeriodData,
    successMessage,
    allExpensesResponse,
  ];
}

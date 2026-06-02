import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/accountant/data/model/accountant_statistics_model.dart';
import '../../../../features/accountant/data/model/add_expense_request_model.dart';
import '../../../../features/accountant/data/model/all_expenses_response_model.dart';
import '../../../../features/admin/data/model/admin_statistics_model.dart';
import '../../../errors/exception.dart';
import '../../app_constants.dart';
import '../../repo/statistics_repo/statistics_repo.dart';

part 'statistics_state.dart';

class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit(this._statisticsRepo) : super(const StatisticsState());
  final StatisticsRepo _statisticsRepo;

  Future<void> getAdminStatistics() async {
    emit(state.copyWith(status: StatisticsStatus.getStatisticsLoading));
    try {
      final statistics = await _statisticsRepo.getAdminStatistics();
      emit(
        state.copyWith(
          status: StatisticsStatus.getStatisticsSuccess,
          adminStatistics: statistics,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StatisticsStatus.getStatisticsFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> getAccountantStatistics() async {
    emit(state.copyWith(status: StatisticsStatus.getStatisticsLoading));
    try {
      final statistics = await _statisticsRepo.getAccountantStatistics();
      emit(
        state.copyWith(
          status: StatisticsStatus.getStatisticsSuccess,
          accountantStatistics: statistics,
          currentPeriodData: statistics.daily,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StatisticsStatus.getStatisticsFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> getAllExpenses() async {
    emit(state.copyWith(status: StatisticsStatus.getAllExpensesLoading));
    try {
      final allExpenses = await _statisticsRepo.getAllExpenses();
      emit(
        state.copyWith(
          status: StatisticsStatus.getAllExpensesSuccess,
          allExpensesResponse: allExpenses,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StatisticsStatus.getAllExpensesFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void getPeriodData(String period) {
    PeriodData currentPeriod = state.accountantStatistics!.daily;
    if (period == periodOptions[0]) {
      currentPeriod = state.accountantStatistics!.daily;
    } else if (period == periodOptions[1]) {
      currentPeriod = state.accountantStatistics!.weekly;
    } else if (period == periodOptions[2]) {
      currentPeriod = state.accountantStatistics!.monthly;
    } else if (period == periodOptions[3]) {
      currentPeriod = state.accountantStatistics!.quarterly;
    } else if (period == periodOptions[4]) {
      currentPeriod = state.accountantStatistics!.semiAnnually;
    } else {
      currentPeriod = state.accountantStatistics!.yearly;
    }
    emit(
      state.copyWith(
        status: StatisticsStatus.getStatisticsSuccess,
        currentPeriodData: currentPeriod,
      ),
    );
  }

  Future<void> addExpense({required AddExpenseRequestModel model}) async {
    emit(state.copyWith(status: StatisticsStatus.addExpenseLoading));
    try {
      final expenseId = await _statisticsRepo.addExpense(model: model);
      emit(
        state.copyWith(
          status: StatisticsStatus.addExpenseSuccess,
          successMessage: 'تم اضافة المصروف بنجاح',
        ),
      );
      final newTotalCost =
          state.allExpensesResponse!.totalExpenses + model.cost;
      final newExpenses = List<ExpenseItemModel>.from(
        state.allExpensesResponse!.expenses,
      );
      newExpenses.insert(
        0,
        ExpenseItemModel(
          id: expenseId,
          cost: model.cost,
          description: model.description,
          date: DateTime.now(),
        ),
      );
      final newAllExpenses = AllExpensesResponseModel(
        totalExpenses: newTotalCost,
        expenses: newExpenses,
      );
      emit(
        state.copyWith(
          status: StatisticsStatus.getAllExpensesSuccess,
          allExpensesResponse: newAllExpenses,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StatisticsStatus.addExpenseFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> deleteExpense({
    required String expenseId,
    required num cost,
  }) async {
    emit(state.copyWith(status: StatisticsStatus.deleteExpenseLoading));
    try {
      await _statisticsRepo.deleteExpense(expenseId: expenseId);
      emit(
        state.copyWith(
          status: StatisticsStatus.deleteExpenseSuccess,
          successMessage: 'تم حذف المصروف بنجاح',
        ),
      );
      final newTotalCost = state.allExpensesResponse!.totalExpenses - cost;
      final newExpenses = List<ExpenseItemModel>.from(
        state.allExpensesResponse!.expenses,
      );
      newExpenses.removeWhere((element) => element.id == expenseId);
      final newAllExpenses = AllExpensesResponseModel(
        totalExpenses: newTotalCost,
        expenses: newExpenses,
      );
      emit(
        state.copyWith(
          status: StatisticsStatus.getAllExpensesSuccess,
          allExpensesResponse: newAllExpenses,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StatisticsStatus.deleteExpenseFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }
}

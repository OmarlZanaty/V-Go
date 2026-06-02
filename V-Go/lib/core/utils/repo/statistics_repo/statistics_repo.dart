import '../../../../features/accountant/data/model/accountant_statistics_model.dart';
import '../../../../features/accountant/data/model/add_expense_request_model.dart';
import '../../../../features/accountant/data/model/all_expenses_response_model.dart';
import '../../../../features/admin/data/model/admin_statistics_model.dart';

abstract class StatisticsRepo {
  Future<AdminStatisticsModel> getAdminStatistics();
  Future<AccountantStatisticsModel> getAccountantStatistics();
  Future<String> addExpense({required AddExpenseRequestModel model});
  Future<void> deleteExpense({required String expenseId});
  Future<AllExpensesResponseModel> getAllExpenses();
}

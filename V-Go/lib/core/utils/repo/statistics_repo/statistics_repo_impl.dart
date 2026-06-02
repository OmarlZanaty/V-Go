import '../../../../features/accountant/data/model/accountant_statistics_model.dart';
import '../../../../features/accountant/data/model/add_expense_request_model.dart';
import '../../../../features/accountant/data/model/all_expenses_response_model.dart';
import '../../../../features/admin/data/model/admin_statistics_model.dart';
import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import 'statistics_repo.dart';

class StatisticsRepoImpl implements StatisticsRepo {
  final ApiServices _apiServices;

  StatisticsRepoImpl({required ApiServices apiServices})
    : _apiServices = apiServices;
  @override
  Future<AccountantStatisticsModel> getAccountantStatistics() async {
    final response = await _apiServices.get(EndPoint.accountantStatistics);
    return AccountantStatisticsModel.fromJson(response['data']);
  }

  @override
  Future<AdminStatisticsModel> getAdminStatistics() async {
    final response = await _apiServices.get(EndPoint.numbersStatistics);
    return AdminStatisticsModel.fromJson(response);
  }

  @override
  Future<String> addExpense({required AddExpenseRequestModel model}) async {
    final response = await _apiServices.post(EndPoint.addExpense, data: model.toJson());
    return response['data']['id'];
  }

  @override
  Future<void> deleteExpense({required String expenseId}) async {
    return await _apiServices.delete(EndPoint.deleteExpense(expenseId));
  }

  @override
  Future<AllExpensesResponseModel> getAllExpenses() async {
    final response = await _apiServices.get(EndPoint.allExpenses);
    return AllExpensesResponseModel.fromJson(response);
  }
}

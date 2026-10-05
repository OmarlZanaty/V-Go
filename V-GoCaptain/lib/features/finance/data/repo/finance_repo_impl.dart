import '../../../../core/api/api_envelope.dart';
import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../models/finance_models.dart';
import 'finance_repo.dart';

class FinanceRepoImpl implements FinanceRepo {
  FinanceRepoImpl({required ApiServices apiServices}) : _api = apiServices;

  final ApiServices _api;

  @override
  Future<FinanceSummary> getSummary() async {
    final data = ApiEnvelope.data(
      await _api.get(EndPoint.driverFinanceSummary),
    );
    return FinanceSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<FinanceLedgerPage> getLedger({
    required int pageNumber,
    int pageSize = 20,
    String? type,
  }) async {
    final data = ApiEnvelope.data(
      await _api.get(
        EndPoint.driverFinanceLedger,
        queryParameters: {
          'pageNumber': pageNumber,
          'pageSize': pageSize,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      ),
    );
    return FinanceLedgerPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<FinanceEligibility> getEligibility() async {
    final data = ApiEnvelope.data(
      await _api.get(EndPoint.driverFinanceEligibility),
    );
    return FinanceEligibility.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> updatePayoutAccount({
    required String method,
    required String account,
    required String accountName,
    required String password,
  }) async {
    ApiEnvelope.data(
      await _api.put(
        EndPoint.driverFinancePayoutAccount,
        data: {
          'method': method,
          'account': account,
          'accountName': accountName,
          'password': password,
        },
      ),
    );
  }

  @override
  Future<FinanceSettlementCheckout> createSettlement() async {
    final data = ApiEnvelope.data(
      await _api.post(EndPoint.driverFinanceSettle),
    );
    return FinanceSettlementCheckout.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  @override
  Future<void> confirmPaymentCallback(String redirectUrl) async {
    ApiEnvelope.data(
      await _api.post(
        EndPoint.paymentConfirmCallback,
        data: {'query': redirectUrl},
      ),
    );
  }

  @override
  Future<FinanceSettlementStatus> getSettlementStatus(String paymentId) async {
    final data = ApiEnvelope.data(
      await _api.get(EndPoint.driverFinanceSettleStatus(paymentId)),
    );
    return FinanceSettlementStatus.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }
}

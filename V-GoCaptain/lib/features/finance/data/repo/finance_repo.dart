import '../models/finance_models.dart';

abstract class FinanceRepo {
  Future<FinanceSummary> getSummary();
  Future<FinanceLedgerPage> getLedger({
    required int pageNumber,
    int pageSize = 20,
    String? type,
  });
  Future<FinanceEligibility> getEligibility();
  Future<void> updatePayoutAccount({
    required String method,
    required String account,
    required String accountName,
    required String password,
  });
  Future<FinanceSettlementCheckout> createSettlement();
  Future<void> confirmPaymentCallback(String redirectUrl);
  Future<FinanceSettlementStatus> getSettlementStatus(String paymentId);
}

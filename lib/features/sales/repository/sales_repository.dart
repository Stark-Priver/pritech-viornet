import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';

class SalesRepository {
  final SupabaseDataService _service;

  SalesRepository(this._service);

  Future<Sale> createSale(Map<String, dynamic> fields) =>
      _service.createSale(fields);

  Future<Sale> makeSale({
    int? voucherId,
    required int agentId,
    required double amount,
    int? clientId,
    int? siteId,
    double commission = 0.0,
    String paymentMethod = 'CASH',
    String? notes,
  }) =>
      _service.makeSale(
        voucherId: voucherId,
        agentId: agentId,
        amount: amount,
        clientId: clientId,
        siteId: siteId,
        commission: commission,
        paymentMethod: paymentMethod,
        notes: notes,
      );

  Future<List<Sale>> getAllSales() => _service.getAllSales();

  Future<Sale?> getSaleById(int id) => _service.getSaleById(id);

  Future<Sale?> getSaleByReceiptNumber(String receipt) =>
      _service.getSaleByReceiptNumber(receipt);

  Future<List<Sale>> getSalesByAgent(int agentId) =>
      _service.getSalesByAgent(agentId);

  Future<List<Sale>> getSalesBySite(int siteId) =>
      _service.getSalesBySite(siteId);

  Future<List<Sale>> getSalesByDateRange(
          DateTime startDate, DateTime endDate) =>
      _service.getSalesByDateRange(startDate, endDate);

  Future<List<Sale>> getTodaySales() => _service.getTodaySales();

  Future<List<Sale>> getThisMonthSales() => _service.getThisMonthSales();

  Future<bool> updateSale(int id, Map<String, dynamic> fields) =>
      _service.updateSale(id, fields);

  Future<void> deleteSale(int id) => _service.deleteSale(id);

  Future<double> getTotalRevenue() => _service.getTotalRevenue();

  Future<double> getRevenueByDateRange(
          DateTime startDate, DateTime endDate) =>
      _service.getRevenueByDateRange(startDate, endDate);

  Future<double> getTodayRevenue() => _service.getTodayRevenue();

  Future<double> getThisMonthRevenue() => _service.getThisMonthRevenue();

  Future<double> getAgentCommissions(
    int agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _service.getAgentCommissions(agentId,
          startDate: startDate, endDate: endDate);

  Future<int> getSalesCount() => _service.getSalesCount();

  Future<List<Sale>> getSalesPaginated(
          {required int page, required int pageSize}) =>
      _service.getSalesPaginated(page: page, pageSize: pageSize);

  Future<Map<String, dynamic>> getSalesStatistics() async {
    final allSales = await getAllSales();
    final todaySales = await getTodaySales();
    final monthSales = await getThisMonthSales();
    return {
      'total_sales': allSales.length,
      'today_sales': todaySales.length,
      'month_sales': monthSales.length,
      'total_revenue':
          allSales.fold<double>(0.0, (sum, sale) => sum + sale.amount),
      'today_revenue':
          todaySales.fold<double>(0.0, (sum, sale) => sum + sale.amount),
      'month_revenue':
          monthSales.fold<double>(0.0, (sum, sale) => sum + sale.amount),
      'total_commission': allSales.fold<double>(
          0.0, (sum, sale) => sum + sale.commission),
    };
  }
}

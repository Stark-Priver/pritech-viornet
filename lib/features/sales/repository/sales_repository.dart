import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class SalesRepository {
  final AppDatabase _database;

  SalesRepository(this._database);

  // Create sale
  Future<int> createSale(SalesCompanion sale) async {
    return await _database.into(_database.sales).insert(sale);
  }

  // Create sale with receipt number generation
  Future<int> makeSale({
    required int voucherId,
    required int agentId,
    required double amount,
    int? clientId,
    int? siteId,
    double commission = 0.0,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    final receiptNumber = _generateReceiptNumber();

    return await _database.into(_database.sales).insert(
          SalesCompanion.insert(
            receiptNumber: receiptNumber,
            voucherId: Value(voucherId),
            clientId: clientId != null ? Value(clientId) : const Value.absent(),
            agentId: agentId,
            siteId: siteId != null ? Value(siteId) : const Value.absent(),
            amount: amount,
            commission: Value(commission),
            paymentMethod: paymentMethod,
            notes: notes != null ? Value(notes) : const Value.absent(),
            saleDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  // Get all sales
  Future<List<Sale>> getAllSales() async {
    return await _database.select(_database.sales).get();
  }

  // Get sale by ID
  Future<Sale?> getSaleById(int id) async {
    return await (_database.select(
      _database.sales,
    )..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get sale by receipt number
  Future<Sale?> getSaleByReceiptNumber(String receiptNumber) async {
    return await (_database.select(_database.sales)
          ..where((tbl) => tbl.receiptNumber.equals(receiptNumber)))
        .getSingleOrNull();
  }

  // Get sales by agent
  Future<List<Sale>> getSalesByAgent(int agentId) async {
    return await (_database.select(
      _database.sales,
    )..where((tbl) => tbl.agentId.equals(agentId)))
        .get();
  }

  // Get sales by site
  Future<List<Sale>> getSalesBySite(int siteId) async {
    return await (_database.select(
      _database.sales,
    )..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  // Get sales by date range
  Future<List<Sale>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await (_database.select(_database.sales)
          ..where(
            (tbl) =>
                tbl.saleDate.isBiggerOrEqualValue(startDate) &
                tbl.saleDate.isSmallerOrEqualValue(endDate),
          ))
        .get();
  }

  // Get today's sales
  Future<List<Sale>> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return await getSalesByDateRange(startOfDay, endOfDay);
  }

  // Get this month's sales
  Future<List<Sale>> getThisMonthSales() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return await getSalesByDateRange(startOfMonth, endOfMonth);
  }

  // Update sale
  Future<bool> updateSale(int id, SalesCompanion sale) async {
    return await (_database.update(
          _database.sales,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          sale.copyWith(
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Delete sale
  Future<int> deleteSale(int id) async {
    return await (_database.delete(
      _database.sales,
    )..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get total revenue
  Future<double> getTotalRevenue() async {
    final sales = await getAllSales();
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.amount);
  }

  // Get revenue by date range
  Future<double> getRevenueByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getSalesByDateRange(startDate, endDate);
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.amount);
  }

  // Get today's revenue
  Future<double> getTodayRevenue() async {
    final sales = await getTodaySales();
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.amount);
  }

  // Get this month's revenue
  Future<double> getThisMonthRevenue() async {
    final sales = await getThisMonthSales();
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.amount);
  }

  // Get agent commissions
  Future<double> getAgentCommissions(
    int agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Sale> sales;

    if (startDate != null && endDate != null) {
      sales = await (_database.select(_database.sales)
            ..where(
              (tbl) =>
                  tbl.agentId.equals(agentId) &
                  tbl.saleDate.isBiggerOrEqualValue(startDate) &
                  tbl.saleDate.isSmallerOrEqualValue(endDate),
            ))
          .get();
    } else {
      sales = await getSalesByAgent(agentId);
    }

    return sales.fold<double>(0.0, (sum, sale) => sum + sale.commission);
  }

  // Get sales count
  Future<int> getSalesCount() async {
    final sales = await getAllSales();
    return sales.length;
  }

  // Get sales with pagination
  Future<List<Sale>> getSalesPaginated({
    required int page,
    required int pageSize,
  }) async {
    final offset = (page - 1) * pageSize;
    return await (_database.select(_database.sales)
          ..orderBy([(t) => OrderingTerm.desc(t.saleDate)])
          ..limit(pageSize, offset: offset))
        .get();
  }

  // Get sales statistics
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
        0.0,
        (sum, sale) => sum + sale.commission,
      ),
    };
  }

  // Helper: Generate receipt number
  String _generateReceiptNumber() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'RCP-$dateStr-$timeStr';
  }
}

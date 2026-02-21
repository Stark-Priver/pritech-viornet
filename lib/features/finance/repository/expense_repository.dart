import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';

class ExpenseRepository {
  final SupabaseDataService _service;

  ExpenseRepository(this._service);

  Future<Expense> createExpense(Map<String, dynamic> fields) =>
      _service.createExpense(fields);

  Future<List<Expense>> getAllExpenses() => _service.getAllExpenses();

  Future<Expense?> getExpenseById(int id) => _service.getExpenseById(id);

  Future<List<Expense>> getExpensesByCategory(String category) =>
      _service.getExpensesByCategory(category);

  Future<List<Expense>> getExpensesBySite(int siteId) =>
      _service.getExpensesBySite(siteId);

  Future<List<Expense>> getExpensesByDateRange(
          DateTime startDate, DateTime endDate) =>
      _service.getExpensesByDateRange(startDate, endDate);

  Future<List<Expense>> getThisMonthExpenses() =>
      _service.getThisMonthExpenses();

  Future<bool> updateExpense(int id, Map<String, dynamic> fields) =>
      _service.updateExpense(id, fields);

  Future<void> deleteExpense(int id) => _service.deleteExpense(id);

  Future<double> getTotalExpenses() => _service.getTotalExpenses();

  Future<double> getExpensesTotalByDateRange(
          DateTime startDate, DateTime endDate) =>
      _service.getExpensesTotalByDateRange(startDate, endDate);

  Future<double> getThisMonthTotalExpenses() =>
      _service.getThisMonthTotalExpenses();

  Future<Map<String, double>> getExpensesByCategoryTotal() =>
      _service.getExpensesByCategoryTotal();
}

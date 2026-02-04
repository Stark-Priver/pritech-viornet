import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class ExpenseRepository {
  final AppDatabase _database;

  ExpenseRepository(this._database);

  // Create expense
  Future<int> createExpense(ExpensesCompanion expense) async {
    return await _database.into(_database.expenses).insert(expense);
  }

  // Get all expenses
  Future<List<Expense>> getAllExpenses() async {
    return await _database.select(_database.expenses).get();
  }

  // Get expense by ID
  Future<Expense?> getExpenseById(int id) async {
    return await (_database.select(_database.expenses)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    return await (_database.select(_database.expenses)
          ..where((tbl) => tbl.category.equals(category)))
        .get();
  }

  // Get expenses by site
  Future<List<Expense>> getExpensesBySite(int siteId) async {
    return await (_database.select(_database.expenses)
          ..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  // Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(
      DateTime startDate, DateTime endDate) async {
    return await (_database.select(_database.expenses)
          ..where((tbl) =>
              tbl.expenseDate.isBiggerOrEqualValue(startDate) &
              tbl.expenseDate.isSmallerOrEqualValue(endDate)))
        .get();
  }

  // Get this month's expenses
  Future<List<Expense>> getThisMonthExpenses() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return await getExpensesByDateRange(startOfMonth, endOfMonth);
  }

  // Update expense
  Future<bool> updateExpense(int id, ExpensesCompanion expense) async {
    return await (_database.update(_database.expenses)
              ..where((tbl) => tbl.id.equals(id)))
            .write(expense.copyWith(
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        )) >
        0;
  }

  // Delete expense
  Future<int> deleteExpense(int id) async {
    return await (_database.delete(_database.expenses)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get total expenses
  Future<double> getTotalExpenses() async {
    final expenses = await getAllExpenses();
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get expenses total by date range
  Future<double> getExpensesTotalByDateRange(
      DateTime startDate, DateTime endDate) async {
    final expenses = await getExpensesByDateRange(startDate, endDate);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get this month's total expenses
  Future<double> getThisMonthTotalExpenses() async {
    final expenses = await getThisMonthExpenses();
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get expenses by category total
  Future<Map<String, double>> getExpensesByCategoryTotal() async {
    final expenses = await getAllExpenses();
    final Map<String, double> categoryTotals = {};

    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    return categoryTotals;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
      ),
      body: FutureBuilder<_ReportData>(
        future: _generateReportData(database),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard('Clients', data.totalClients.toString(),
                  Icons.people, Colors.blue),
              _buildSummaryCard('Active Clients', data.activeClients.toString(),
                  Icons.check_circle, Colors.green),
              _buildSummaryCard(
                  'Total Sales',
                  CurrencyFormatter.format(data.totalSales),
                  Icons.attach_money,
                  Colors.green),
              _buildSummaryCard(
                  'This Month',
                  CurrencyFormatter.format(data.monthSales),
                  Icons.calendar_today,
                  Colors.orange),
              _buildSummaryCard(
                  'Total Expenses',
                  CurrencyFormatter.format(data.totalExpenses),
                  Icons.payment,
                  Colors.red),
              _buildSummaryCard(
                  'Net Revenue',
                  CurrencyFormatter.format(
                      data.totalSales - data.totalExpenses),
                  Icons.trending_up,
                  Colors.purple),
              const SizedBox(height: 24),
              const Text(
                'Sales by Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...data.salesByPayment.entries.map((entry) {
                return Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      CurrencyFormatter.format(entry.value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              const Text(
                'Top Performing Sites',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...data.topSites.entries.take(5).map((entry) {
                return Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      CurrencyFormatter.format(entry.value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_ReportData> _generateReportData(SupabaseDataService database) async {
    // Get clients data
    final allClients = await database.getAllClients();
    final activeClients = allClients.where((c) {
      return c.isActive && (c.expiryDate?.isAfter(DateTime.now()) ?? false);
    }).length;

    // Get sales data
    final allSales = await database.getAllSales();
    final totalSales =
        allSales.fold<double>(0, (sum, sale) => sum + sale.amount);

    // This month sales
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthSales = allSales
        .where((s) => s.saleDate.isAfter(monthStart))
        .fold<double>(0, (sum, sale) => sum + sale.amount);

    // Sales by payment method
    final salesByPayment = <String, double>{};
    for (final sale in allSales) {
      salesByPayment[sale.paymentMethod] =
          (salesByPayment[sale.paymentMethod] ?? 0) + sale.amount;
    }

    // Get expenses
    final allExpenses = await database.getAllExpenses();
    final totalExpenses =
        allExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Top sites by sales
    final sites = await database.getAllSites();
    final topSites = <String, double>{};
    for (final site in sites) {
      final siteSales = allSales.where((s) => s.siteId == site.id);
      final siteTotal = siteSales.fold<double>(0, (sum, s) => sum + s.amount);
      if (siteTotal > 0) {
        topSites[site.name] = siteTotal;
      }
    }

    return _ReportData(
      totalClients: allClients.length,
      activeClients: activeClients,
      totalSales: totalSales,
      monthSales: monthSales,
      totalExpenses: totalExpenses,
      salesByPayment: salesByPayment,
      topSites: Map.fromEntries(
        topSites.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      ),
    );
  }
}

class _ReportData {
  final int totalClients;
  final int activeClients;
  final double totalSales;
  final double monthSales;
  final double totalExpenses;
  final Map<String, double> salesByPayment;
  final Map<String, double> topSites;

  _ReportData({
    required this.totalClients,
    required this.activeClients,
    required this.totalSales,
    required this.monthSales,
    required this.totalExpenses,
    required this.salesByPayment,
    required this.topSites,
  });
}

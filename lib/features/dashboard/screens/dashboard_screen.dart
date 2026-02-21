import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/agent_commission_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // Check if user can see financial data
    final canSeeFinancials = !authState.userRoles.contains('AGENT');

    return FutureBuilder<DashboardData>(
      future: _fetchDashboardData(
        database,
        authNotifier.canAccessAllSites,
        authNotifier.currentUserSites,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data ?? DashboardData.empty();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 768;
              final isMobile = constraints.maxWidth < 768;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  GridView.count(
                    crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: isMobile ? 1.2 : 1.5,
                    children: [
                      _buildStatCard(
                        context,
                        'Total Clients',
                        '${data.totalClients}',
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        context,
                        'Active Vouchers',
                        '${data.activeVouchers}',
                        Icons.confirmation_number,
                        Colors.green,
                      ),
                      // Hide financial data from agents
                      if (canSeeFinancials) ...[
                        _buildStatCard(
                          context,
                          'Today Sales',
                          CurrencyFormatter.format(data.todaySales),
                          Icons.attach_money,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          context,
                          'Total Revenue',
                          CurrencyFormatter.format(data.totalRevenue),
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Agent Commission Widget - Show only for agents
                  if (authState.userRoles.contains('AGENT') ||
                      authState.userRoles.contains('SALES'))
                    const AgentCommissionWidget(),

                  if (authState.userRoles.contains('AGENT') ||
                      authState.userRoles.contains('SALES'))
                    const SizedBox(height: 24),

                  // Charts - Hide from agents
                  if (canSeeFinancials) ...[
                    if (isMobile) ...[
                      _buildSalesChart(context, data.last7DaysSales),
                      const SizedBox(height: 16),
                      _buildVoucherChart(context, data.voucherStats),
                    ] else
                      Row(
                        children: [
                          Expanded(
                              child: _buildSalesChart(
                                  context, data.last7DaysSales)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildVoucherChart(
                                  context, data.voucherStats)),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Recent Activities
                  _buildRecentActivities(context, data.recentSales),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<DashboardData> _fetchDashboardData(
    SupabaseDataService database,
    bool canAccessAllSites,
    List<int> userSites,
  ) async {
    return database.getDashboardData(
      canAccessAllSites: canAccessAllSites,
      userSites: userSites,
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Icon(icon, color: color, size: 28),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, List<double> salesData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Overview (Last 7 Days)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: salesData.isEmpty || salesData.every((s) => s == 0)
                  ? const Center(child: Text('No sales data available'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun'
                                ];
                                if (value.toInt() >= 0 &&
                                    value.toInt() < days.length) {
                                  return Text(days[value.toInt()],
                                      style: const TextStyle(fontSize: 10));
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${(value / 1000).toStringAsFixed(0)}K',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              salesData.length,
                              (index) =>
                                  FlSpot(index.toDouble(), salesData[index]),
                            ),
                            isCurved: true,
                            color: Theme.of(context).primaryColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherChart(BuildContext context, VoucherStats stats) {
    final total = stats.active + stats.sold + stats.expired + stats.unused;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voucher Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: total == 0
                  ? const Center(child: Text('No vouchers available'))
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                if (stats.active > 0)
                                  PieChartSectionData(
                                    value: stats.active.toDouble(),
                                    title:
                                        '${((stats.active / total) * 100).toStringAsFixed(0)}%',
                                    color: Colors.green,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (stats.sold > 0)
                                  PieChartSectionData(
                                    value: stats.sold.toDouble(),
                                    title:
                                        '${((stats.sold / total) * 100).toStringAsFixed(0)}%',
                                    color: Colors.blue,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (stats.expired > 0)
                                  PieChartSectionData(
                                    value: stats.expired.toDouble(),
                                    title:
                                        '${((stats.expired / total) * 100).toStringAsFixed(0)}%',
                                    color: Colors.orange,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (stats.unused > 0)
                                  PieChartSectionData(
                                    value: stats.unused.toDouble(),
                                    title:
                                        '${((stats.unused / total) * 100).toStringAsFixed(0)}%',
                                    color: Colors.red,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                                'Active', Colors.green, stats.active),
                            _buildLegendItem('Sold', Colors.blue, stats.sold),
                            _buildLegendItem(
                                'Expired', Colors.orange, stats.expired),
                            _buildLegendItem(
                                'Unused', Colors.red, stats.unused),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label: $count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentActivities(BuildContext context, List<Sale> recentSales) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Sales',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (recentSales.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No recent sales'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentSales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final sale = recentSales[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child:
                          const Icon(Icons.attach_money, color: Colors.white),
                    ),
                    title: Text('Receipt: ${sale.receiptNumber}'),
                    subtitle: Text(
                      '${sale.saleDate.day}/${sale.saleDate.month}/${sale.saleDate.year} - ${sale.paymentMethod}',
                    ),
                    trailing: Text(
                      CurrencyFormatter.format(sale.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

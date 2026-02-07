import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' as drift hide Column;
import 'package:drift/drift.dart' show Expression;
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/database.dart';
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
    AppDatabase database,
    bool canAccessAllSites,
    List<int> userSites,
  ) async {
    // Site filter for queries
    Expression<bool>? siteFilter;
    if (!canAccessAllSites && userSites.isNotEmpty) {
      siteFilter = database.clients.siteId.isIn(userSites);
    }

    // Total clients
    final clientsQuery = database.selectOnly(database.clients)
      ..addColumns([database.clients.id.count()]);
    if (siteFilter != null) {
      clientsQuery.where(siteFilter);
    }
    final totalClients = await clientsQuery
        .map((row) => row.read(database.clients.id.count()) ?? 0)
        .getSingle();

    // Available vouchers count
    final vouchersQuery = database.select(database.vouchers)
      ..where((tbl) => tbl.status.equals('AVAILABLE'));
    final activeVouchers = await vouchersQuery.get().then((v) => v.length);

    // Today's sales - filter by client's site
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final todaySalesJoin = database.selectOnly(database.sales).join([
      drift.innerJoin(
        database.clients,
        database.clients.id.equalsExp(database.sales.clientId),
      ),
    ]);
    todaySalesJoin.addColumns([database.sales.amount.sum()]);
    todaySalesJoin
        .where(database.sales.saleDate.isBiggerOrEqualValue(startOfDay));
    if (siteFilter != null) {
      todaySalesJoin.where(siteFilter);
    }
    final todaySalesAmount = await todaySalesJoin
        .map((row) => row.read(database.sales.amount.sum()) ?? 0.0)
        .getSingle();

    // Total revenue - filter by client's site
    final revenueJoin = database.selectOnly(database.sales).join([
      drift.innerJoin(
        database.clients,
        database.clients.id.equalsExp(database.sales.clientId),
      ),
    ]);
    revenueJoin.addColumns([database.sales.amount.sum()]);
    if (siteFilter != null) {
      revenueJoin.where(siteFilter);
    }
    final totalRevenue = await revenueJoin
        .map((row) => row.read(database.sales.amount.sum()) ?? 0.0)
        .getSingle();

    // Last 7 days sales - filter by client's site
    final last7Days = <DateTime>[];
    for (int i = 6; i >= 0; i--) {
      last7Days.add(DateTime(today.year, today.month, today.day - i));
    }

    final dailySales = <double>[];
    for (final day in last7Days) {
      final nextDay = day.add(const Duration(days: 1));
      final dayJoin = database.selectOnly(database.sales).join([
        drift.innerJoin(
          database.clients,
          database.clients.id.equalsExp(database.sales.clientId),
        ),
      ]);
      dayJoin.addColumns([database.sales.amount.sum()]);
      dayJoin.where(database.sales.saleDate.isBiggerOrEqualValue(day) &
          database.sales.saleDate.isSmallerThanValue(nextDay));
      if (siteFilter != null) {
        dayJoin.where(siteFilter);
      }
      final amount = await dayJoin
          .map((row) => row.read(database.sales.amount.sum()) ?? 0.0)
          .getSingle();
      dailySales.add(amount);
    }

    // Voucher stats by status
    Future<int> voucherStatusQuery(String status) async {
      final query = database.selectOnly(database.vouchers);
      query.addColumns([database.vouchers.id.count()]);
      query.where(database.vouchers.status.equals(status));
      return await query
          .map((row) => row.read(database.vouchers.id.count()) ?? 0)
          .getSingle();
    }

    final voucherCounts = await Future.wait([
      voucherStatusQuery('ACTIVE'),
      voucherStatusQuery('SOLD'),
      voucherStatusQuery('EXPIRED'),
      voucherStatusQuery('UNUSED'),
    ]);

    // Recent sales - filter by client's site
    final recentSalesJoin = database.select(database.sales).join([
      drift.innerJoin(
        database.clients,
        database.clients.id.equalsExp(database.sales.clientId),
      ),
    ]);
    recentSalesJoin.orderBy([drift.OrderingTerm.desc(database.sales.saleDate)]);
    recentSalesJoin.limit(5);
    if (siteFilter != null) {
      recentSalesJoin.where(siteFilter);
    }
    final recentSales =
        await recentSalesJoin.map((row) => row.readTable(database.sales)).get();

    return DashboardData(
      totalClients: totalClients,
      activeVouchers: activeVouchers,
      todaySales: todaySalesAmount,
      totalRevenue: totalRevenue,
      last7DaysSales: dailySales,
      voucherStats: VoucherStats(
        active: voucherCounts[0],
        sold: voucherCounts[1],
        expired: voucherCounts[2],
        unused: voucherCounts[3],
      ),
      recentSales: recentSales,
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

// Data models
class DashboardData {
  final int totalClients;
  final int activeVouchers;
  final double todaySales;
  final double totalRevenue;
  final List<double> last7DaysSales;
  final VoucherStats voucherStats;
  final List<Sale> recentSales;

  DashboardData({
    required this.totalClients,
    required this.activeVouchers,
    required this.todaySales,
    required this.totalRevenue,
    required this.last7DaysSales,
    required this.voucherStats,
    required this.recentSales,
  });

  factory DashboardData.empty() {
    return DashboardData(
      totalClients: 0,
      activeVouchers: 0,
      todaySales: 0,
      totalRevenue: 0,
      last7DaysSales: List.filled(7, 0),
      voucherStats: VoucherStats(active: 0, sold: 0, expired: 0, unused: 0),
      recentSales: [],
    );
  }
}

class VoucherStats {
  final int active;
  final int sold;
  final int expired;
  final int unused;

  VoucherStats({
    required this.active,
    required this.sold,
    required this.expired,
    required this.unused,
  });
}

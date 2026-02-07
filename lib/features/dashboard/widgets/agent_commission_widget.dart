import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

class AgentCommissionWidget extends ConsumerWidget {
  const AgentCommissionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final db = ref.watch(databaseProvider);

    if (authState.user == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getCommissionSummary(db, authState.user!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final summary = snapshot.data!;
        final totalPending = summary['pending'] ?? 0.0;
        final totalApproved = summary['approved'] ?? 0.0;
        final totalPaid = summary['paid'] ?? 0.0;
        final totalCommission = totalPending + totalApproved + totalPaid;

        return Card(
          elevation: 4,
          child: InkWell(
            onTap: () =>
                _showCommissionDetails(context, db, authState.user!.id),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Commissions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.monetization_on,
                          color: Colors.green[700], size: 28),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatColumn(
                        'Total',
                        CurrencyFormatter.format(totalCommission),
                        Colors.blue,
                      ),
                      _buildStatColumn(
                        'Pending',
                        CurrencyFormatter.format(totalPending),
                        Colors.orange,
                      ),
                      _buildStatColumn(
                        'Approved',
                        CurrencyFormatter.format(totalApproved),
                        Colors.green,
                      ),
                      _buildStatColumn(
                        'Paid',
                        CurrencyFormatter.format(totalPaid),
                        Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showCommissionDetails(
                          context, db, authState.user!.id),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getCommissionSummary(
      AppDatabase db, int agentId) async {
    final commissions = await (db.select(db.commissionHistory)
          ..where((tbl) => tbl.agentId.equals(agentId)))
        .get();

    double pending = 0.0;
    double approved = 0.0;
    double paid = 0.0;

    for (final commission in commissions) {
      switch (commission.status) {
        case 'PENDING':
          pending += commission.commissionAmount;
          break;
        case 'APPROVED':
          approved += commission.commissionAmount;
          break;
        case 'PAID':
          paid += commission.commissionAmount;
          break;
      }
    }

    return {
      'pending': pending,
      'approved': approved,
      'paid': paid,
      'count': commissions.length,
    };
  }

  void _showCommissionDetails(
      BuildContext context, AppDatabase db, int agentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return CommissionDetailsSheet(
            db: db,
            agentId: agentId,
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

class CommissionDetailsSheet extends StatelessWidget {
  final AppDatabase db;
  final int agentId;
  final ScrollController scrollController;

  const CommissionDetailsSheet({
    super.key,
    required this.db,
    required this.agentId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Commission History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getCommissionHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final commissions = snapshot.data ?? [];

                if (commissions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.money_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No commission history yet'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: commissions.length,
                  itemBuilder: (context, index) {
                    final item = commissions[index];
                    final commission =
                        item['commission'] as CommissionHistoryData;
                    final sale = item['sale'] as Sale?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(commission.status),
                          child: Icon(
                            _getStatusIcon(commission.status),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          CurrencyFormatter.format(commission.commissionAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                                'Sale: ${CurrencyFormatter.format(commission.saleAmount)}'),
                            Text(
                                'Rate: ${commission.commissionRate?.toStringAsFixed(1)}%'),
                            Text('Date: ${_formatDate(commission.createdAt)}'),
                            if (sale != null) Text('Ref: Sale #${sale.id}'),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            commission.status,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: _getStatusColor(commission.status),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getCommissionHistory() async {
    final results = await (db.select(db.commissionHistory).join([
      leftOuterJoin(
          db.sales, db.sales.id.equalsExp(db.commissionHistory.saleId)),
    ])
          ..where(db.commissionHistory.agentId.equals(agentId))
          ..orderBy([OrderingTerm.desc(db.commissionHistory.createdAt)]))
        .get();

    return results.map((row) {
      return {
        'commission': row.readTable(db.commissionHistory),
        'sale': row.readTableOrNull(db.sales),
      };
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'PAID':
        return Colors.teal;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'APPROVED':
        return Icons.check_circle;
      case 'PAID':
        return Icons.payment;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

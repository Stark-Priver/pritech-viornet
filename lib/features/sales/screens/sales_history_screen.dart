import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by receipt or client...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                label: Text(
                  '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                ),
                onDeleted: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<_SaleWithDetails>>(
              future: _getFilteredSales(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final sales = snapshot.data ?? [];

                if (sales.isEmpty) {
                  return const Center(child: Text('No sales found'));
                }

                final totalAmount = sales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.sale.amount,
                );
                final totalCommission = sales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.sale.commission,
                );

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${sales.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Sales'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                CurrencyFormatter.format(totalAmount),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text('Total'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                CurrencyFormatter.format(totalCommission),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const Text('Commission'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sales.length,
                        itemBuilder: (context, index) {
                          final saleData = sales[index];
                          return _buildSaleCard(saleData);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(_SaleWithDetails saleData) {
    final sale = saleData.sale;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sale.receiptNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getPaymentColor(sale.paymentMethod),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sale.paymentMethod,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (saleData.clientName != null)
              Text(
                'Client: ${saleData.clientName}',
                style: TextStyle(color: Colors.grey[700]),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      CurrencyFormatter.format(sale.amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (sale.commission > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Commission',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        CurrencyFormatter.format(sale.commission),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(sale.saleDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentColor(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return Colors.green;
      case 'MPESA':
      case 'MOBILE_MONEY':
        return Colors.orange;
      case 'BANK':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showFilterDialog() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  Future<List<_SaleWithDetails>> _getFilteredSales(AppDatabase database) async {
    var query = database.select(database.sales)
      ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]);

    final allSales = await query.get();
    final results = <_SaleWithDetails>[];

    for (final sale in allSales) {
      String? clientName;
      if (sale.clientId != null) {
        final client = await (database.select(database.clients)
              ..where((t) => t.id.equals(sale.clientId!)))
            .getSingleOrNull();
        clientName = client?.name;
      }

      results.add(_SaleWithDetails(sale: sale, clientName: clientName));
    }

    // Apply date filter
    var filtered = results;
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((item) {
        final date = item.sale.saleDate;
        return date.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.sale.receiptNumber.toLowerCase().contains(_searchQuery) ||
            (item.clientName?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    return filtered;
  }
}

class _SaleWithDetails {
  final Sale sale;
  final String? clientName;

  _SaleWithDetails({required this.sale, this.clientName});
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import 'add_voucher_screen.dart';

class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  String _statusFilter = 'All';
  String _searchQuery = '';
  int _rebuildKey = 0;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vouchers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddVoucherScreen(),
                ),
              ).then((_) => setState(() {
                    _rebuildKey++;
                  }));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search vouchers...',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('UNUSED'),
                _buildFilterChip('SOLD'),
                _buildFilterChip('ACTIVE'),
                _buildFilterChip('EXPIRED'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Voucher>>(
              key: ValueKey(_rebuildKey),
              future: _getFilteredVouchers(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final vouchers = snapshot.data ?? [];

                if (vouchers.isEmpty) {
                  return const Center(
                    child: Text('No vouchers found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _rebuildKey++;
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vouchers.length,
                    itemBuilder: (context, index) {
                      final voucher = vouchers[index];
                      return _buildVoucherCard(voucher);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _statusFilter = label;
            _rebuildKey++;
          });
        },
      ),
    );
  }

  Widget _buildVoucherCard(Voucher voucher) {
    Color statusColor;
    IconData statusIcon;

    switch (voucher.status) {
      case 'UNUSED':
        statusColor = Colors.blue;
        statusIcon = Icons.inventory_2;
        break;
      case 'SOLD':
        statusColor = Colors.orange;
        statusIcon = Icons.shopping_cart;
        break;
      case 'ACTIVE':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'EXPIRED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.code,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPackageNameFromDuration(voucher.duration),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${voucher.duration} Days',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    voucher.status,
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
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.attach_money,
                  CurrencyFormatter.format(voucher.price),
                ),
                if (voucher.username != null)
                  _buildInfoItem(Icons.person, voucher.username!),
                if (voucher.soldAt != null)
                  _buildInfoItem(
                    Icons.calendar_today,
                    'Sold: ${_formatDate(voucher.soldAt!)}',
                  ),
              ],
            ),
            if (voucher.expiresAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Expires: ${_formatDate(voucher.expiresAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getPackageNameFromDuration(int duration) {
    switch (duration) {
      case 7:
        return '1 Week Package';
      case 14:
        return '2 Weeks Package';
      case 30:
        return '1 Month Package';
      case 90:
        return '3 Months Package';
      default:
        return 'Custom Package';
    }
  }

  Future<List<Voucher>> _getFilteredVouchers(AppDatabase database) async {
    final allVouchers = await database.select(database.vouchers).get();

    var vouchers = allVouchers;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      vouchers = vouchers.where((voucher) {
        return voucher.code.toLowerCase().contains(_searchQuery) ||
            (voucher.username?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != 'All') {
      vouchers = vouchers.where((voucher) {
        return voucher.status == _statusFilter;
      }).toList();
    }

    return vouchers;
  }
}

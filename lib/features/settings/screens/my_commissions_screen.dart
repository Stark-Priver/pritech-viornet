import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

class MyCommissionsScreen extends ConsumerStatefulWidget {
  const MyCommissionsScreen({super.key});

  @override
  ConsumerState<MyCommissionsScreen> createState() =>
      _MyCommissionsScreenState();
}

class _MyCommissionsScreenState extends ConsumerState<MyCommissionsScreen> {
  List<CommissionHistory> _history = [];
  bool _isLoading = false;
  String? _error;
  String _filter = 'ALL';

  static const _filters = ['ALL', 'PENDING', 'APPROVED', 'PAID', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final userId = ref.read(authProvider).user?.id;
      if (userId == null) throw Exception('Not authenticated');

      final history = await db.getCommissionHistoryByAgent(userId);

      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<CommissionHistory> get _filtered => _filter == 'ALL'
      ? _history
      : _history.where((c) => c.status == _filter).toList();

  // Totals
  double get _totalPending => _history
      .where((c) => c.status == 'PENDING')
      .fold(0.0, (s, c) => s + c.commissionAmount);

  double get _totalApproved => _history
      .where((c) => c.status == 'APPROVED')
      .fold(0.0, (s, c) => s + c.commissionAmount);

  double get _totalPaid => _history
      .where((c) => c.status == 'PAID')
      .fold(0.0, (s, c) => s + c.commissionAmount);

  double get _totalEarned => _totalPending + _totalApproved + _totalPaid;

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.blue;
      case 'PAID':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'APPROVED':
        return Icons.thumb_up_outlined;
      case 'PAID':
        return Icons.check_circle_outline;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Commissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    // ── Hero Summary Card ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildHeroCard(user, primaryColor),
                    ),

                    // ── Stat Row ───────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildStatRow(),
                    ),

                    // ── Filter Chips ───────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildFilterChips(),
                    ),

                    // ── Section label ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'TRANSACTION HISTORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),

                    // ── History List ───────────────────────────────────────
                    _filtered.isEmpty
                        ? SliverFillRemaining(child: _buildEmpty())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _buildCard(_filtered[i]),
                              childCount: _filtered.length,
                            ),
                          ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 24),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeroCard(dynamic user, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'My Account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_history.length} commission record${_history.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Earned',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(_totalEarned),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar: paid vs total
          if (_totalEarned > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _totalPaid / _totalEarned,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(_totalPaid / _totalEarned * 100).toStringAsFixed(0)}% of total commissions paid out',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _statCard(
            label: 'Pending',
            amount: _totalPending,
            count: _history.where((c) => c.status == 'PENDING').length,
            color: Colors.orange,
            icon: Icons.hourglass_empty,
          ),
          const SizedBox(width: 8),
          _statCard(
            label: 'Approved',
            amount: _totalApproved,
            count: _history.where((c) => c.status == 'APPROVED').length,
            color: Colors.blue,
            icon: Icons.thumb_up_outlined,
          ),
          const SizedBox(width: 8),
          _statCard(
            label: 'Paid',
            amount: _totalPaid,
            count: _history.where((c) => c.status == 'PAID').length,
            color: Colors.green,
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required double amount,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              CurrencyFormatter.formatCompact(amount),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final f = _filters[i];
            final selected = _filter == f;
            final count = f == 'ALL'
                ? _history.length
                : _history.where((c) => c.status == f).length;
            return ChoiceChip(
              label: Text(
                '$f ($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(CommissionHistory item) {
    final statusColor = _statusColor(item.status);
    final statusIcon = _statusIcon(item.status);
    final date = item.createdAt.toLocal();
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = '${date.day} ${months[date.month]} ${date.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(statusIcon, size: 20, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                CurrencyFormatter.format(item.commissionAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _metaChip(
                    Icons.confirmation_number,
                    'Sale #${item.saleId}',
                  ),
                  const SizedBox(width: 10),
                  if (item.commissionRate != null)
                    _metaChip(
                      Icons.percent,
                      '${(item.commissionRate! * 100).toStringAsFixed(1)}%',
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  _metaChip(
                    Icons.shopping_bag_outlined,
                    'Sale: ${CurrencyFormatter.format(item.saleAmount)}',
                  ),
                  const SizedBox(width: 10),
                  _metaChip(Icons.calendar_today_outlined, dateStr),
                ],
              ),
              if (item.paidAt != null) ...[
                const SizedBox(height: 3),
                _metaChip(
                  Icons.payments_outlined,
                  'Paid: ${item.paidAt!.toLocal().day} ${months[item.paidAt!.toLocal().month]} ${item.paidAt!.toLocal().year}',
                  color: Colors.green.shade600,
                ),
              ],
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _metaChip(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _filter == 'ALL'
                ? 'No commission records yet'
                : 'No ${_filter.toLowerCase()} commissions',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete sales to earn commissions',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }
}

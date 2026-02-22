import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';

class CommissionDemandsScreen extends ConsumerStatefulWidget {
  const CommissionDemandsScreen({super.key});

  @override
  ConsumerState<CommissionDemandsScreen> createState() =>
      _CommissionDemandsScreenState();
}

class _CommissionDemandsScreenState
    extends ConsumerState<CommissionDemandsScreen> {
  List<CommissionHistory> _allHistory = [];
  Map<int, String> _userNames = {};
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
      final results = await Future.wait([
        db.getAllCommissionHistory(),
        db.getAllUsers(),
      ]);

      final history = results[0] as List<CommissionHistory>;
      final users = results[1] as List<AppUser>;

      if (!mounted) return;
      setState(() {
        _allHistory = history;
        _userNames = {for (final u in users) u.id: u.name};
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

  List<CommissionHistory> get _filteredHistory => _filter == 'ALL'
      ? _allHistory
      : _allHistory.where((c) => c.status == _filter).toList();

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

  Future<void> _approveCommission(CommissionHistory item) async {
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id;
    final db = ref.read(databaseProvider);

    try {
      await db.updateCommissionHistory(item.id, {
        'status': 'APPROVED',
        'approved_by': currentUserId,
        'approved_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission approved successfully'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving commission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsPaid(CommissionHistory item) async {
    final db = ref.read(databaseProvider);

    try {
      await db.updateCommissionHistory(item.id, {
        'status': 'PAID',
        'paid_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating commission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelCommission(CommissionHistory item) async {
    final db = ref.read(databaseProvider);

    try {
      await db.updateCommissionHistory(item.id, {'status': 'CANCELLED'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling commission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmAction({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    Color? confirmColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Demands'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary banner
          if (!_isLoading && _error == null) _buildSummaryBanner(),

          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final selected = _filter == f;
                  final count = f == 'ALL'
                      ? _allHistory.length
                      : _allHistory.where((c) => c.status == f).length;
                  return FilterChip(
                    label: Text('$f ($count)'),
                    selected: selected,
                    selectedColor: _filterChipColor(f).withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _filter = f),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Body
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Color _filterChipColor(String filter) {
    switch (filter) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.blue;
      case 'PAID':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Widget _buildSummaryBanner() {
    if (_allHistory.isEmpty) return const SizedBox.shrink();

    final pending = _allHistory.where((c) => c.status == 'PENDING').length;
    final approved = _allHistory.where((c) => c.status == 'APPROVED').length;
    final totalPending = _allHistory
        .where((c) => c.status == 'PENDING')
        .fold(0.0, (sum, c) => sum + c.commissionAmount);
    final totalApproved = _allHistory
        .where((c) => c.status == 'APPROVED')
        .fold(0.0, (sum, c) => sum + c.commissionAmount);

    final fmt = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
            'Pending',
            pending.toString(),
            fmt.format(totalPending),
            Colors.orange,
            Icons.hourglass_empty,
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _summaryItem(
            'Approved',
            approved.toString(),
            fmt.format(totalApproved),
            Colors.blue,
            Icons.thumb_up_outlined,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label, String count, String amount, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          count,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          amount,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
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

    final items = _filteredHistory;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _filter == 'ALL'
                  ? 'No commission demands found'
                  : 'No ${_filter.toLowerCase()} commissions',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(CommissionHistory item) {
    final agentName = _userNames[item.agentId] ?? 'Agent #${item.agentId}';
    final commFmt = NumberFormat('#,##0.00').format(item.commissionAmount);
    final saleFmt = NumberFormat('#,##0.00').format(item.saleAmount);
    final dateFmt =
        DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt.toLocal());
    final statusColor = _statusColor(item.status);
    final statusIcon = _statusIcon(item.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(statusIcon, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        dateFmt,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── Amounts ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    label: 'Commission',
                    value: commFmt,
                    valueStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: _infoTile(
                    label: 'Sale amount',
                    value: saleFmt,
                  ),
                ),
                if (item.commissionRate != null)
                  Expanded(
                    child: _infoTile(
                      label: 'Rate',
                      value:
                          '${(item.commissionRate! * 100).toStringAsFixed(1)}%',
                    ),
                  ),
              ],
            ),

            // ── Sale reference ─────────────────────────────────────────────
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.confirmation_number,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Sale #${item.saleId}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),

            // ── Notes ──────────────────────────────────────────────────────
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.notes, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Approved / Paid timestamps ─────────────────────────────────
            if (item.approvedAt != null || item.paidAt != null) ...[
              const SizedBox(height: 4),
              if (item.approvedAt != null)
                Text(
                  'Approved: ${DateFormat('dd MMM yyyy').format(item.approvedAt!.toLocal())}',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade400),
                ),
              if (item.paidAt != null)
                Text(
                  'Paid: ${DateFormat('dd MMM yyyy').format(item.paidAt!.toLocal())}',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade500),
                ),
            ],

            // ── Action buttons ─────────────────────────────────────────────
            if (item.status == 'PENDING' || item.status == 'APPROVED') ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.status == 'PENDING') ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _confirmAction(
                        title: 'Cancel Commission?',
                        message: 'Mark this commission demand as cancelled?',
                        confirmColor: Colors.red,
                        onConfirm: () => _cancelCommission(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _confirmAction(
                        title: 'Approve Commission?',
                        message: 'Approve $commFmt commission for $agentName?',
                        confirmColor: Colors.blue,
                        onConfirm: () => _approveCommission(item),
                      ),
                    ),
                  ],
                  if (item.status == 'APPROVED')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payments, size: 14),
                      label: const Text('Mark as Paid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _confirmAction(
                        title: 'Mark as Paid?',
                        message:
                            'Mark $commFmt commission for $agentName as paid?',
                        confirmColor: Colors.green,
                        onConfirm: () => _markAsPaid(item),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../auth/providers/auth_provider.dart';

class InvestorsScreen extends ConsumerStatefulWidget {
  const InvestorsScreen({super.key});

  @override
  ConsumerState<InvestorsScreen> createState() => _InvestorsScreenState();
}

class _InvestorsScreenState extends ConsumerState<InvestorsScreen> {
  final _db = SupabaseDataService();

  List<Investor> _investors = [];
  bool _loading = true;
  double _netProfit = 0;
  double _totalRevenue = 0;
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getAllInvestors(),
        _db.getTotalRevenue(),
        _db.getTotalExpenses(),
      ]);
      if (mounted) {
        setState(() {
          _investors = results[0] as List<Investor>;
          _totalRevenue = results[1] as double;
          _totalExpenses = results[2] as double;
          _netProfit = _totalRevenue - _totalExpenses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load data: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ADD / EDIT DIALOG
  // ─────────────────────────────────────────────────────────────

  Future<void> _openDialog({Investor? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final amountCtrl = TextEditingController(
        text:
            existing != null ? existing.investedAmount.toStringAsFixed(2) : '');
    final roiCtrl = TextEditingController(
        text:
            existing != null ? existing.roiPercentage.toStringAsFixed(3) : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime investDate = existing?.investDate ?? DateTime.now();
    String returnPeriod = existing?.returnPeriod ?? 'MONTHLY';
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Header ───
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          existing == null ? 'Add Investor' : 'Edit Investor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // ─── Form ───
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            _buildField(
                                nameCtrl, 'Full Name *', Icons.person_outline,
                                required: true),
                            const SizedBox(height: 14),
                            _buildField(
                                emailCtrl, 'Email', Icons.email_outlined),
                            const SizedBox(height: 14),
                            _buildField(
                                phoneCtrl, 'Phone', Icons.phone_outlined),
                            const SizedBox(height: 14),
                            _buildField(
                              amountCtrl,
                              'Invested Amount (TZS) *',
                              Icons.attach_money,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              required: true,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(v.trim()) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            // Invest Date picker
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: investDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) setDlg(() => investDate = d);
                              },
                              child: InputDecorator(
                                decoration: _inputDeco('Investment Date *',
                                    Icons.calendar_today_outlined),
                                child: Text(
                                  '${investDate.day.toString().padLeft(2, '0')}/'
                                  '${investDate.month.toString().padLeft(2, '0')}/'
                                  '${investDate.year}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildField(
                              roiCtrl,
                              'ROI % of Net Profit *',
                              Icons.percent,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              required: true,
                              hint: 'e.g. 10 means 10% of net profit',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                final parsed = double.tryParse(v.trim());
                                if (parsed == null) {
                                  return 'Enter a valid number';
                                }
                                if (parsed < 0 || parsed > 100) {
                                  return 'Must be 0–100';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            // Return Period dropdown
                            DropdownButtonFormField<String>(
                              initialValue: returnPeriod,
                              decoration: _inputDeco(
                                  'Return Period', Icons.access_time_outlined),
                              items: const [
                                DropdownMenuItem(
                                    value: 'MONTHLY', child: Text('Monthly')),
                                DropdownMenuItem(
                                    value: 'QUARTERLY',
                                    child: Text('Quarterly (every 3 months)')),
                                DropdownMenuItem(
                                    value: 'ANNUALLY', child: Text('Annually')),
                              ],
                              onChanged: (v) =>
                                  setDlg(() => returnPeriod = v ?? 'MONTHLY'),
                            ),
                            const SizedBox(height: 14),
                            _buildField(notesCtrl, 'Notes', Icons.notes),
                            const SizedBox(height: 10),
                            if (existing != null)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Active investor'),
                                value: isActive,
                                activeThumbColor: const Color(0xFF2563EB),
                                onChanged: (v) => setDlg(() => isActive = v),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ─── Actions ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              Navigator.pop(ctx);
                              await _save(
                                existing: existing,
                                nameCtrl: nameCtrl,
                                emailCtrl: emailCtrl,
                                phoneCtrl: phoneCtrl,
                                amountCtrl: amountCtrl,
                                roiCtrl: roiCtrl,
                                notesCtrl: notesCtrl,
                                investDate: investDate,
                                returnPeriod: returnPeriod,
                                isActive: isActive,
                              );
                            },
                            child: Text(
                                existing == null ? 'Add Investor' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save({
    Investor? existing,
    required TextEditingController nameCtrl,
    required TextEditingController emailCtrl,
    required TextEditingController phoneCtrl,
    required TextEditingController amountCtrl,
    required TextEditingController roiCtrl,
    required TextEditingController notesCtrl,
    required DateTime investDate,
    required String returnPeriod,
    required bool isActive,
  }) async {
    final fields = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'invested_amount': double.parse(amountCtrl.text.trim()),
      'invest_date': investDate.toIso8601String().split('T').first,
      'roi_percentage': double.parse(roiCtrl.text.trim()),
      'return_period': returnPeriod,
      'is_active': isActive,
    };
    if (emailCtrl.text.trim().isNotEmpty) {
      fields['email'] = emailCtrl.text.trim();
    }
    if (phoneCtrl.text.trim().isNotEmpty) {
      fields['phone'] = phoneCtrl.text.trim();
    }
    if (notesCtrl.text.trim().isNotEmpty) {
      fields['notes'] = notesCtrl.text.trim();
    }

    try {
      if (existing == null) {
        await _db.createInvestor(fields);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Investor added'), backgroundColor: Colors.green),
          );
        }
      } else {
        await _db.updateInvestor(existing.id, fields);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Investor updated'),
                backgroundColor: Colors.green),
          );
        }
      }
      await _loadData();
    } catch (e) {
      if (mounted) _showError('Error: $e');
    }
  }

  Future<void> _confirmDelete(Investor investor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Investor'),
        content: Text(
            'Are you sure you want to remove "${investor.name}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _db.deleteInvestor(investor.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Investor deleted'),
                backgroundColor: Colors.orange),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) _showError('Error: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────

  InputDecoration _inputDeco(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool required = false,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: _inputDeco(label, icon, hint: hint),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    );
  }

  String _formatCurrency(double v) {
    if (v >= 1000000) {
      return 'TZS ${(v / 1000000).toStringAsFixed(2)}M';
    }
    if (v >= 1000) {
      return 'TZS ${(v / 1000).toStringAsFixed(1)}K';
    }
    return 'TZS ${v.toStringAsFixed(2)}';
  }

  String _periodLabel(String p) {
    switch (p) {
      case 'MONTHLY':
        return 'Monthly';
      case 'QUARTERLY':
        return 'Quarterly';
      case 'ANNUALLY':
        return 'Annually';
      default:
        return p;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userRoles = authState.userRoles;
    final canManage =
        userRoles.any((r) => ['ADMIN', 'SUPER_ADMIN', 'FINANCE'].contains(r));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investors'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Investor'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                ),
                onPressed: () => _openDialog(),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // ─── Summary Panel ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Net Profit Header
                          _buildProfitBanner(),
                          const SizedBox(height: 16),
                          if (_investors.isNotEmpty) ...[
                            const Text(
                              'Investor Returns (based on current net profit)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._investors
                                .where((i) => i.isActive)
                                .map((i) => _buildReturnChip(i)),
                          ],
                          if (_investors.isEmpty) _buildEmptyState(canManage),
                        ],
                      ),
                    ),
                  ),

                  // ─── Investor List ───
                  if (_investors.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildInvestorCard(_investors[i], canManage),
                          ),
                          childCount: _investors.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfitBanner() {
    final profitPositive = _netProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: profitPositive
              ? [const Color(0xFF059669), const Color(0xFF047857)]
              : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (profitPositive ? Colors.green : Colors.red)
                .withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('Net Profit Overview',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _profitItem('Total Revenue',
                    _formatCurrency(_totalRevenue), Colors.white70),
              ),
              Expanded(
                child: _profitItem('Total Expenses',
                    _formatCurrency(_totalExpenses), Colors.white70),
              ),
              Expanded(
                child: _profitItem(
                    'Net Profit',
                    '${profitPositive ? '+' : ''}${_formatCurrency(_netProfit)}',
                    Colors.white,
                    large: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profitItem(String label, String value, Color textColor,
      {bool large = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: textColor.withValues(alpha: 0.8), fontSize: 11)),
        Text(value,
            style: TextStyle(
                color: textColor,
                fontSize: large ? 16 : 14,
                fontWeight: large ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildReturnChip(Investor investor) {
    final returnAmount = investor.calculateReturn(_netProfit);
    final isPositive = returnAmount >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, size: 16, color: Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              investor.name,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${investor.roiPercentage.toStringAsFixed(1)}% → ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          Text(
            '${isPositive ? '+' : ''}${_formatCurrency(returnAmount)} /${_periodLabel(investor.returnPeriod).toLowerCase()}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isPositive
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestorCard(Investor investor, bool canManage) {
    final returnAmount = investor.calculateReturn(_netProfit);
    final profitPositive = returnAmount >= 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFF2563EB).withValues(alpha: 0.1),
                  child: Text(
                    investor.name.isNotEmpty
                        ? investor.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(investor.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF111827))),
                      if (investor.email != null)
                        Text(investor.email!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                // Active badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: investor.isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: investor.isActive
                            ? Colors.green.shade200
                            : Colors.grey.shade300),
                  ),
                  child: Text(
                    investor.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 11,
                        color: investor.isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Stats row
            Row(
              children: [
                _statChip(
                    Icons.attach_money,
                    'Invested',
                    _formatCurrency(investor.investedAmount),
                    const Color(0xFF2563EB)),
                const SizedBox(width: 10),
                _statChip(
                    Icons.percent,
                    'ROI',
                    '${investor.roiPercentage.toStringAsFixed(1)}%',
                    const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                _statChip(
                    Icons.access_time_outlined,
                    'Period',
                    _periodLabel(investor.returnPeriod),
                    const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 12),
            // Projected return
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    profitPositive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: profitPositive
                        ? Colors.green.shade200
                        : Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    profitPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: profitPositive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Return (${_periodLabel(investor.returnPeriod)}): ',
                    style: TextStyle(
                        fontSize: 12,
                        color: profitPositive
                            ? Colors.green.shade800
                            : Colors.red.shade800),
                  ),
                  Text(
                    '${profitPositive ? '+' : ''}${_formatCurrency(returnAmount)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: profitPositive
                            ? Colors.green.shade800
                            : Colors.red.shade800),
                  ),
                ],
              ),
            ),
            if (investor.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                investor.notes!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (canManage) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB)),
                    onPressed: () => _openDialog(existing: investor),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600),
                    onPressed: () => _confirmDelete(investor),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 10, color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool canManage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No investors yet',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              'Add investors to track their returns\nbased on net profit.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            if (canManage) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add First Investor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _openDialog(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

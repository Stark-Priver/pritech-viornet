import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

bool _canManageSales(List<String> roles) =>
    roles.any((r) => r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'FINANCE');

const _paymentMethods = ['CASH', 'MPESA', 'BANK', 'CARD', 'OTHER'];

Color _pmColor(String pm) {
  switch (pm.toUpperCase()) {
    case 'CASH':
      return const Color(0xFF10B981);
    case 'MPESA':
    case 'MOBILE_MONEY':
      return const Color(0xFFF59E0B);
    case 'BANK':
      return const Color(0xFF3B82F6);
    case 'CARD':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF6B7280);
  }
}

IconData _pmIcon(String pm) {
  switch (pm.toUpperCase()) {
    case 'CASH':
      return Icons.payments_rounded;
    case 'MPESA':
    case 'MOBILE_MONEY':
      return Icons.phone_android_rounded;
    case 'BANK':
      return Icons.account_balance_rounded;
    case 'CARD':
      return Icons.credit_card_rounded;
    default:
      return Icons.receipt_rounded;
  }
}

//  Screen

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  String? _pmFilter; // null = all
  int _rebuildKey = 0;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _rebuildKey++);

  //  build
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final authState = ref.watch(authProvider);
    final canManage = _canManageSales(authState.userRoles);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sales History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Date Filter',
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Record Sale',
              onPressed: () => _showSaleDialog(db, null),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: Column(
        children: [
          //  Search & filter bar
          Container(
            color: const Color(0xFF2563EB),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search receipt, client',
                hintStyle: const TextStyle(color: Color(0xFFBFDBFE)),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Color(0xFFBFDBFE)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFFBFDBFE)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1D4ED8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          //  Payment-method filter chips
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: [
                _pmChip(null, 'All'),
                ..._paymentMethods.map((pm) => _pmChip(pm, pm)),
              ],
            ),
          ),
          //  Active date range chip
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Chip(
                avatar: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                    '${DateFormat('dd MMM').format(_startDate!)}  ${DateFormat('dd MMM yyyy').format(_endDate!)}'),
                onDeleted: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
                backgroundColor: const Color(0xFFEFF6FF),
                side: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
          //  List
          Expanded(
            child: FutureBuilder<List<_SaleItem>>(
              key: ValueKey(_rebuildKey),
              future: _fetchSales(db),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text('Error: ${snap.error}',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No sales found',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                        if (canManage) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Record Sale'),
                            onPressed: () => _showSaleDialog(db, null),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final totalAmt =
                    items.fold<double>(0, (s, i) => s + i.sale.amount);
                final totalComm =
                    items.fold<double>(0, (s, i) => s + i.sale.commission);

                return Column(
                  children: [
                    // Summary banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: .35),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryCol('${items.length}', 'Sales',
                              Icons.receipt_rounded, Colors.white),
                          _vDivider(),
                          _summaryCol(
                              CurrencyFormatter.format(totalAmt),
                              'Revenue',
                              Icons.trending_up_rounded,
                              const Color(0xFF6EE7B7)),
                          _vDivider(),
                          _summaryCol(
                              CurrencyFormatter.format(totalComm),
                              'Commission',
                              Icons.toll_rounded,
                              const Color(0xFFFCD34D)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: items.length,
                        itemBuilder: (_, i) =>
                            _buildCard(items[i], db, canManage),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showSaleDialog(db, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record Sale'),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  //  Helpers

  Widget _pmChip(String? pm, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      _pmFilter == pm ? FontWeight.w600 : FontWeight.normal)),
          selected: _pmFilter == pm,
          onSelected: (_) => setState(() => _pmFilter = pm),
          selectedColor: const Color(0xFFDBEAFE),
          checkmarkColor: const Color(0xFF2563EB),
        ),
      );

  Widget _summaryCol(
          String value, String label, IconData icon, Color valueColor) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: valueColor, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11)),
      ]);

  Widget _vDivider() => Container(
      height: 40, width: 1, color: Colors.white.withValues(alpha: .25));

  //  Sale card
  Widget _buildCard(_SaleItem item, SupabaseDataService db, bool canManage) {
    final s = item.sale;
    final color = _pmColor(s.paymentMethod);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canManage ? () => _showSaleDialog(db, s) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(_pmIcon(s.paymentMethod), color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.receiptNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        if (item.agentName != null)
                          Text('Agent: ${item.agentName}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF3B82F6))),
                      ],
                    ),
                  ),
                  // PM badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s.paymentMethod,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Client & date
              if (item.clientName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(item.clientName!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ]),
                ),
              Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(_fmtDate(s.saleDate),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ]),
              const SizedBox(height: 10),
              // Amount row + actions
              Row(
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                        Text(CurrencyFormatter.format(s.amount),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981))),
                      ]),
                  if (s.commission > 0) ...[
                    const SizedBox(width: 20),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Commission',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF9CA3AF))),
                          Text(CurrencyFormatter.format(s.commission),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF59E0B))),
                        ]),
                  ],
                  const Spacer(),
                  if (canManage) ...[
                    _actionBtn(
                      icon: Icons.edit_rounded,
                      color: const Color(0xFF3B82F6),
                      tooltip: 'Edit Sale',
                      onTap: () => _showSaleDialog(db, s),
                    ),
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      tooltip: 'Delete Sale',
                      onTap: () => _confirmDelete(db, s),
                    ),
                  ],
                ],
              ),
              if (s.notes != null && s.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s.notes!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
          {required IconData icon,
          required Color color,
          required String tooltip,
          required VoidCallback onTap}) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  //  Data fetch
  Future<List<_SaleItem>> _fetchSales(SupabaseDataService db) async {
    final auth = ref.read(authProvider.notifier);
    final canAll = auth.canAccessAllSites;
    final me = auth.currentUser;

    List<Sale> raw;
    if (canAll) {
      raw = await db.getAllSales();
    } else {
      if (me == null) return [];
      raw = await db.getSalesByAgent(me.id);
    }
    raw.sort((a, b) => b.saleDate.compareTo(a.saleDate));

    Map<int, String> agentMap = {};
    if (canAll) {
      final users = await db.getAllUsers();
      agentMap = {for (final u in users) u.id: u.name};
    }

    final out = <_SaleItem>[];
    for (final s in raw) {
      String? clientName;
      if (s.clientId != null) {
        clientName = (await db.getClientById(s.clientId!))?.name;
      }
      out.add(_SaleItem(
        sale: s,
        clientName: clientName,
        agentName: canAll ? agentMap[s.agentId] : null,
      ));
    }

    var res = out;
    if (_startDate != null && _endDate != null) {
      res = res.where((i) {
        final d = i.sale.saleDate;
        return d.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            d.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }
    if (_pmFilter != null) {
      res = res
          .where((i) =>
              i.sale.paymentMethod.toUpperCase() == _pmFilter!.toUpperCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      res = res.where((i) {
        return i.sale.receiptNumber.toLowerCase().contains(_searchQuery) ||
            (i.clientName?.toLowerCase().contains(_searchQuery) ?? false) ||
            (i.agentName?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }
    return res;
  }

  //  Delete
  Future<void> _confirmDelete(SupabaseDataService db, Sale s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 12),
          const Text('Delete Sale',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to permanently delete this sale?',
                style: TextStyle(color: Color(0xFF374151))),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receipt: ${s.receiptNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Amount: ${CurrencyFormatter.format(s.amount)}'),
                  Text('Payment: ${s.paymentMethod}'),
                  Text('Date: ${_fmtDate(s.saleDate)}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('This action cannot be undone.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await db.deleteSale(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sale deleted'), backgroundColor: Color(0xFF10B981)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444)));
    }
  }

  //  Add / Edit dialog
  Future<void> _showSaleDialog(SupabaseDataService db, Sale? existing) async {
    final isEdit = existing != null;
    final receiptCtrl = TextEditingController(
        text: existing?.receiptNumber ??
            'RCP-${DateTime.now().millisecondsSinceEpoch}');
    final amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final commCtrl = TextEditingController(
        text: existing != null ? existing.commission.toStringAsFixed(0) : '0');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String pm = existing?.paymentMethod ?? 'CASH';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isEdit
                      ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(isEdit ? 'Edit Sale' : 'Record New Sale',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx, false)),
              ]),
            ),
            // Body
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(builder: (ctx2, setDlg) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lbl('Receipt Number *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: receiptCtrl,
                      decoration: _inp('e.g. RCP-001'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    _lbl('Payment Method *'),
                    const SizedBox(height: 6),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<String>(
                      value: pm, // ignore: deprecated_member_use
                      decoration: _inp('Select payment method'),
                      items: _paymentMethods
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Row(children: [
                                  Icon(_pmIcon(m),
                                      color: _pmColor(m), size: 18),
                                  const SizedBox(width: 8),
                                  Text(m),
                                ]),
                              ))
                          .toList(),
                      onChanged: (v) => setDlg(() => pm = v ?? pm),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _lbl('Amount (TSh) *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: amountCtrl,
                              decoration: _inp('0.00'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _lbl('Commission (TSh)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: commCtrl,
                              decoration: _inp('0.00'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _lbl('Notes (Optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: _inp('Additional info'),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                );
              }),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child:
                          const Text('Cancel', style: TextStyle(fontSize: 15))),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded,
                        size: 18),
                    label: Text(isEdit ? 'Save Changes' : 'Record Sale',
                        style: const TextStyle(fontSize: 15)),
                    style: FilledButton.styleFrom(
                      backgroundColor: isEdit
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                    ),
                    onPressed: () async {
                      if (receiptCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Receipt number is required.', true);
                        return;
                      }
                      final rawAmt = double.tryParse(amountCtrl.text.trim());
                      if (rawAmt == null || rawAmt <= 0) {
                        _snack(ctx, 'Enter a valid amount.', true);
                        return;
                      }
                      final comm = double.tryParse(commCtrl.text.trim()) ?? 0.0;
                      final nav = Navigator.of(ctx);
                      final sm = ScaffoldMessenger.of(context);
                      try {
                        final fields = <String, dynamic>{
                          'receipt_number': receiptCtrl.text.trim(),
                          'payment_method': pm,
                          'amount': rawAmt,
                          'commission': comm,
                          if (notesCtrl.text.trim().isNotEmpty)
                            'notes': notesCtrl.text.trim(),
                        };
                        if (existing != null) {
                          await db.updateSale(existing.id, fields);
                        } else {
                          final auth = ref.read(authProvider.notifier);
                          fields['agent_id'] = auth.currentUser?.id ?? 1;
                          fields['sale_date'] =
                              DateTime.now().toIso8601String();
                          await db.createSale(fields);
                        }
                        nav.pop(true);
                        sm.showSnackBar(SnackBar(
                          content: Text(isEdit
                              ? 'Sale updated successfully'
                              : 'Sale recorded successfully'),
                          backgroundColor: const Color(0xFF10B981),
                        ));
                      } catch (e) {
                        if (ctx.mounted) {
                          _snack(ctx, 'Error: $e', true);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) _refresh();
  }

  //  Dialog helpers
  Widget _lbl(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)));

  InputDecoration _inp(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      );

  void _snack(BuildContext ctx, String msg, bool isErr) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor:
            isErr ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ));

  //  Date range picker
  Future<void> _showDateRangePicker() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }
}

//  Data holder
class _SaleItem {
  final Sale sale;
  final String? clientName;
  final String? agentName;
  const _SaleItem({required this.sale, this.clientName, this.agentName});
}

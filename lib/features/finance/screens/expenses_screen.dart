// =============================================================================
// expenses_screen.dart  â€“  Full CRUD (Create Â· Read Â· Update Â· Delete)
// Role-gated: ADMIN, FINANCE, SUPER_ADMIN can create / edit / delete.
// All users with finance permission can view.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

// â”€â”€â”€ Role helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
bool _canManageExpenses(List<String> roles) =>
    roles.any((r) => r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'FINANCE');

// â”€â”€â”€ Category helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _expenseCategories = [
  'MAINTENANCE',
  'EQUIPMENT',
  'SALARY',
  'UTILITY',
  'FUEL',
  'RENT',
  'INTERNET',
  'OTHER',
];

Color _catColor(String c) {
  switch (c) {
    case 'MAINTENANCE':
      return const Color(0xFFF97316);
    case 'EQUIPMENT':
      return const Color(0xFF3B82F6);
    case 'SALARY':
      return const Color(0xFF10B981);
    case 'UTILITY':
      return const Color(0xFF8B5CF6);
    case 'FUEL':
      return const Color(0xFFEF4444);
    case 'RENT':
      return const Color(0xFF06B6D4);
    case 'INTERNET':
      return const Color(0xFF6366F1);
    default:
      return const Color(0xFF6B7280);
  }
}

IconData _catIcon(String c) {
  switch (c) {
    case 'MAINTENANCE':
      return Icons.build_rounded;
    case 'EQUIPMENT':
      return Icons.devices_rounded;
    case 'SALARY':
      return Icons.people_rounded;
    case 'UTILITY':
      return Icons.electrical_services_rounded;
    case 'FUEL':
      return Icons.local_gas_station_rounded;
    case 'RENT':
      return Icons.home_work_rounded;
    case 'INTERNET':
      return Icons.wifi_rounded;
    default:
      return Icons.payments_rounded;
  }
}

// =============================================================================
// ExpensesScreen  â€“  CRUD UI
// =============================================================================
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  String _categoryFilter = 'All';
  String _searchQuery = '';
  int _rebuildKey = 0;
  late AnimationController _fabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _rebuildKey++);

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final authState = ref.watch(authProvider);
    final canManage = _canManageExpenses(authState.userRoles);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text('Expenses',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search inside blue header
          Container(
            color: const Color(0xFF2563EB),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (v) => setState(() {
                _searchQuery = v.toLowerCase();
                _rebuildKey++;
              }),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search expensesâ€¦',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // Category chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', ..._expenseCategories].map((c) {
                  final sel = _categoryFilter == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c,
                          style: TextStyle(
                            color: sel
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 12,
                          )),
                      selected: sel,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      showCheckmark: false,
                      avatar: c != 'All'
                          ? Icon(_catIcon(c),
                              size: 13,
                              color: sel ? Colors.white : _catColor(c))
                          : null,
                      onSelected: (_) => setState(() {
                        _categoryFilter = c;
                        _rebuildKey++;
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Main list
          Expanded(
            child: FutureBuilder<List<Expense>>(
              key: ValueKey(_rebuildKey),
              future: _fetchExpenses(db),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 8),
                        Text('Error: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[400])),
                      ],
                    ),
                  );
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No expenses found',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[500])),
                        if (canManage) ...[
                          const SizedBox(height: 6),
                          Text('Tap + to record a new expense',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[400])),
                        ],
                      ],
                    ),
                  );
                }

                final total = list.fold<double>(0, (s, e) => s + e.amount);

                return Column(
                  children: [
                    // Summary banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.format(total),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${list.length} expense${list.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) =>
                            _buildExpenseCard(list[i], canManage, db),
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
          ? ScaleTransition(
              scale: CurvedAnimation(
                  parent: _fabAnimCtrl, curve: Curves.elasticOut),
              child: FloatingActionButton.extended(
                onPressed: () => _showExpenseDialog(db, null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Expense'),
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            )
          : null,
    );
  }

  // â”€â”€ Expense card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildExpenseCard(
      Expense expense, bool canManage, SupabaseDataService db) {
    final color = _catColor(expense.category);
    final icon = _catIcon(expense.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canManage ? () => _showExpenseDialog(db, expense) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Category icon circle
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            expense.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy').format(expense.expenseDate),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                    if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        expense.notes!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount + actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(expense.amount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionBtn(Icons.edit_rounded, const Color(0xFF3B82F6),
                            () => _showExpenseDialog(db, expense), 'Edit'),
                        const SizedBox(width: 4),
                        _actionBtn(
                            Icons.delete_rounded,
                            const Color(0xFFEF4444),
                            () => _confirmDelete(db, expense),
                            'Delete'),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, Color color, VoidCallback onTap, String tip) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  // â”€â”€ Data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<List<Expense>> _fetchExpenses(SupabaseDataService db) async {
    List<Expense> all;
    if (_categoryFilter == 'All') {
      all = await db.getAllExpenses();
    } else {
      all = await db.getExpensesByCategory(_categoryFilter);
    }
    if (_searchQuery.isNotEmpty) {
      all = all
          .where((e) =>
              e.description.toLowerCase().contains(_searchQuery) ||
              e.category.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return all;
  }

  // â”€â”€ Delete confirm â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _confirmDelete(SupabaseDataService db, Expense exp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Expense'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permanently delete this expense?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exp.description,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(CurrencyFormatter.format(exp.amount),
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('This action cannot be undone.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await db.deleteExpense(exp.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Expense deleted'),
          backgroundColor: Color(0xFF10B981)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444)));
    }
  }

  // â”€â”€ Add / Edit dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _showExpenseDialog(
      SupabaseDataService db, Expense? existing) async {
    final isEdit = existing != null;
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final receiptCtrl =
        TextEditingController(text: existing?.receiptNumber ?? '');

    String category = existing?.category ?? 'MAINTENANCE';
    DateTime expDate = existing?.expenseDate ?? DateTime.now();

    final authState = ref.read(authProvider);
    final currentUser = authState.user;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isEdit
                          ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                          : [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isEdit
                              ? Icons.edit_rounded
                              : Icons.add_circle_rounded,
                          color: Colors.white,
                          size: 24),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Edit Expense' : 'New Expense',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // â”€â”€ Form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dlgLabel('Category *'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: category,
                          decoration: _dlgInput('Select category'),
                          items: _expenseCategories
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Row(children: [
                                      Icon(_catIcon(c),
                                          size: 18, color: _catColor(c)),
                                      const SizedBox(width: 10),
                                      Text(c),
                                    ]),
                                  ))
                              .toList(),
                          onChanged: (v) => setDs(() => category = v!),
                        ),
                        const SizedBox(height: 16),
                        _dlgLabel('Description *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descCtrl,
                          decoration: _dlgInput('Enter expense description'),
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 16),
                        _dlgLabel('Amount (TSh) *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: amountCtrl,
                          decoration:
                              _dlgInput('0').copyWith(prefixText: 'TSh  '),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                        ),
                        const SizedBox(height: 16),
                        _dlgLabel('Expense Date'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: expDate,
                              firstDate: DateTime(2020),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 1)),
                            );
                            if (d != null) setDs(() => expDate = d);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.outline),
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                            child: Row(children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('MMM dd, yyyy').format(expDate),
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _dlgLabel('Receipt # (Optional)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: receiptCtrl,
                          decoration: _dlgInput('e.g. RCP-0012'),
                        ),
                        const SizedBox(height: 16),
                        _dlgLabel('Notes (Optional)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: _dlgInput('Additional detailsâ€¦'),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ],
                    ),
                  ),
                ),
                // â”€â”€ Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                    border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 15)),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: Icon(
                            isEdit ? Icons.save_rounded : Icons.add_rounded,
                            size: 18),
                        label: Text(isEdit ? 'Save Changes' : 'Add Expense',
                            style: const TextStyle(fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: isEdit
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 14),
                        ),
                        onPressed: () async {
                          if (descCtrl.text.trim().isEmpty) {
                            _dlgSnack(ctx, 'Description is required.', true);
                            return;
                          }
                          final rawAmt =
                              double.tryParse(amountCtrl.text.trim());
                          if (rawAmt == null || rawAmt <= 0) {
                            _dlgSnack(ctx, 'Enter a valid amount.', true);
                            return;
                          }
                          final nav = Navigator.of(ctx);
                          final sm = ScaffoldMessenger.of(context);
                          try {
                            final fields = <String, dynamic>{
                              'category': category,
                              'description': descCtrl.text.trim(),
                              'amount': rawAmt,
                              'expense_date': expDate.toIso8601String(),
                              if (notesCtrl.text.trim().isNotEmpty)
                                'notes': notesCtrl.text.trim(),
                              if (receiptCtrl.text.trim().isNotEmpty)
                                'receipt_number': receiptCtrl.text.trim(),
                            };
                            if (existing != null) {
                              await db.updateExpense(existing.id, fields);
                            } else {
                              fields['created_by'] = currentUser?.id ?? 1;
                              await db.createExpense(fields);
                            }
                            nav.pop(true);
                            sm.showSnackBar(SnackBar(
                              content: Text(
                                  isEdit ? 'Expense updated' : 'Expense added'),
                              backgroundColor: const Color(0xFF10B981),
                            ));
                          } catch (e) {
                            if (ctx.mounted) {
                              _dlgSnack(ctx, 'Error: $e', true);
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
        ),
      ),
    );
    if (ok == true && mounted) _refresh();
  }

  // â”€â”€ Dialog helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _dlgLabel(String t) => Text(t,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface));

  InputDecoration _dlgInput(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  void _dlgSnack(BuildContext ctx, String msg, bool isErr) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isErr ? const Color(0xFFEF4444) : const Color(0xFF10B981),
    ));
  }
}

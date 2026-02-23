import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _categoryFilter = 'All';
  int _rebuildKey = 0;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddExpenseDialog(database),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('MAINTENANCE'),
                _buildFilterChip('EQUIPMENT'),
                _buildFilterChip('SALARY'),
                _buildFilterChip('UTILITY'),
                _buildFilterChip('OTHER'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Expense>>(
              key: ValueKey(_rebuildKey),
              future: _getFilteredExpenses(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return const Center(child: Text('No expenses found'));
                }

                final total =
                    expenses.fold<double>(0, (sum, e) => sum + e.amount);

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${expenses.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Expenses'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                CurrencyFormatter.format(total),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Text('Total Amount'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return _buildExpenseCard(expense);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(database),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _categoryFilter == label,
        onSelected: (selected) => setState(() {
          _categoryFilter = label;
          _rebuildKey++;
        }),
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _getCategoryColor(expense.category).withValues(alpha: 0.2),
          child: Icon(
            _getCategoryIcon(expense.category),
            color: _getCategoryColor(expense.category),
          ),
        ),
        title: Text(expense.description),
        subtitle: Text(
          '${expense.category} • ${_formatDate(expense.expenseDate)}',
        ),
        trailing: Text(
          CurrencyFormatter.format(expense.amount),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'MAINTENANCE':
        return Colors.orange;
      case 'EQUIPMENT':
        return Colors.blue;
      case 'SALARY':
        return Colors.green;
      case 'UTILITY':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'MAINTENANCE':
        return Icons.build;
      case 'EQUIPMENT':
        return Icons.devices;
      case 'SALARY':
        return Icons.people;
      case 'UTILITY':
        return Icons.electrical_services;
      default:
        return Icons.payments;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<List<Expense>> _getFilteredExpenses(
      SupabaseDataService database) async {
    final allExpenses = await database.getAllExpenses();

    if (_categoryFilter == 'All') {
      return allExpenses;
    }

    return allExpenses.where((e) => e.category == _categoryFilter).toList();
  }

  Future<void> _showAddExpenseDialog(SupabaseDataService database) async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String category = 'MAINTENANCE';
    DateTime expenseDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Add New Expense',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: [
                            'MAINTENANCE',
                            'EQUIPMENT',
                            'SALARY',
                            'UTILITY',
                            'OTHER'
                          ].map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                    _getCategoryIcon(c),
                                    size: 20,
                                    color: _getCategoryColor(c),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(c),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => category = v!),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Description *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          decoration: InputDecoration(
                            hintText: 'Enter expense description',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Amount (TSh) *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixText: 'TSh ',
                            prefixStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Expense Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: expenseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => expenseDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[50],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMM dd, yyyy')
                                      .format(expenseDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(Icons.calendar_today,
                                    size: 20, color: Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Notes (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          decoration: InputDecoration(
                            hintText: 'Additional notes',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () async {
                          if (descController.text.isEmpty ||
                              amountController.text.isEmpty) {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please fill in all required fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);

                          // Get current user from database
                          final users = await database.getAllUsers();
                          final currentUser = users.first;

                          await database.createExpense({
                            'category': category,
                            'description': descController.text,
                            'amount': double.parse(amountController.text),
                            'created_by': currentUser.id,
                            'expense_date': expenseDate.toIso8601String(),
                          });

                          nav.pop(true);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Expense added successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'Add Expense',
                          style: TextStyle(fontSize: 16),
                        ),
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

    // Update UI after dialog closes
    if (result == true && mounted) {
      setState(() {
        _rebuildKey++;
      });
    }
  }
}

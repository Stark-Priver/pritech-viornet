import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../repository/sales_repository.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commissionController = TextEditingController();
  final _searchController = TextEditingController();

  Client? _selectedClient;
  String _paymentMethod = 'CASH';
  String _saleType = 'VOUCHER';
  bool _isLoading = false;
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commissionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final database = ref.read(databaseProvider);
    final clients = await (database.select(database.clients)
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();
    setState(() {
      _clients = clients;
    });
  }

  Future<void> _createSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final database = ref.read(databaseProvider);
      final repository = SalesRepository(database);

      // Get current user from database
      final users = await database.select(database.users).get();
      final currentUser = users.first;

      // Use makeSale helper which generates receipt number
      await repository.makeSale(
        voucherId:
            1, // Note: Using default voucher, implement voucher selection if needed
        agentId: currentUser.id,
        clientId: _selectedClient!.id,
        amount: double.parse(_amountController.text),
        paymentMethod: _paymentMethod,
        commission: _commissionController.text.isEmpty
            ? 0
            : double.parse(_commissionController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedClient = null;
      _amountController.clear();
      _commissionController.clear();
      _searchController.clear();
      _paymentMethod = 'CASH';
      _saleType = 'VOUCHER';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Client',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search client',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedClient != null)
                      ListTile(
                        leading: CircleAvatar(
                            child:
                                Text(_selectedClient!.name[0].toUpperCase())),
                        title: Text(_selectedClient!.name),
                        subtitle: Text(_selectedClient!.phone),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _selectedClient = null),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _getFilteredClients().length,
                          itemBuilder: (context, index) {
                            final client = _getFilteredClients()[index];
                            return ListTile(
                              leading: CircleAvatar(
                                  child: Text(client.name[0].toUpperCase())),
                              title: Text(client.name),
                              subtitle: Text(client.phone),
                              onTap: () => setState(() {
                                _selectedClient = client;
                                _searchController.clear();
                              }),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sale Details',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _saleType,
                      decoration: const InputDecoration(
                          labelText: 'Sale Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'VOUCHER', child: Text('Voucher')),
                        DropdownMenuItem(
                            value: 'RENEWAL', child: Text('Renewal')),
                        DropdownMenuItem(
                            value: 'UPGRADE', child: Text('Upgrade')),
                      ],
                      onChanged: (value) => setState(() => _saleType = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText:
                            'Amount (${CurrencyFormatter.currencySymbol})',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'MPESA', child: Text('M-PESA')),
                        DropdownMenuItem(
                            value: 'BANK', child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) =>
                          setState(() => _paymentMethod = value!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createSale,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete Sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Client> _getFilteredClients() {
    if (_searchController.text.isEmpty) return _clients.take(5).toList();
    final query = _searchController.text.toLowerCase();
    return _clients
        .where((c) =>
            c.name.toLowerCase().contains(query) || c.phone.contains(query))
        .take(5)
        .toList();
  }
}

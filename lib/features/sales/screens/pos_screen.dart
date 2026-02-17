import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
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
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _voucherCodeController = TextEditingController();

  Client? _selectedClient;
  Site? _selectedSite;
  Package? _selectedPackage;
  Voucher? _selectedVoucher;
  String _paymentMethod = 'CASH';
  String _saleType = 'VOUCHER';
  bool _isLoading = false;
  bool _isWalkIn = false;
  bool _showNewClientForm = false;
  List<Client> _clients = [];
  List<Site> _sites = [];
  List<Package> _packages = [];
  List<Voucher> _availableVouchers = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadSites();
    _loadPackages();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commissionController.dispose();
    _searchController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _voucherCodeController.dispose();
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

  Future<void> _loadSites() async {
    final database = ref.read(databaseProvider);
    final sites = await (database.select(database.sites)
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();
    setState(() {
      _sites = sites;
      if (_sites.isNotEmpty && _selectedSite == null) {
        _selectedSite = _sites.first;
      }
    });
  }

  Future<void> _loadPackages() async {
    final database = ref.read(databaseProvider);
    final packages = await (database.select(database.packages)
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();
    setState(() {
      _packages = packages;
    });
  }

  Future<void> _loadAvailableVouchers({int? packageId}) async {
    final voucherService = ref.read(voucherServiceProvider);
    final vouchers =
        await voucherService.getAvailableVouchers(packageId: packageId);
    setState(() {
      _availableVouchers = vouchers;
      _selectedVoucher = null;
    });
  }

  Future<void> _searchVoucherByCode(String code) async {
    if (code.isEmpty) return;

    final voucherService = ref.read(voucherServiceProvider);
    final voucher = await voucherService.getVoucherByCode(code);

    if (voucher != null && voucher.status == 'AVAILABLE') {
      setState(() {
        _selectedVoucher = voucher;
        if (voucher.price != null) {
          _amountController.text = voucher.price.toString();
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(voucher == null
                ? 'Voucher not found'
                : 'Voucher already ${voucher.status.toLowerCase()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createSale() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate site selection
    if (_selectedSite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a site'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate voucher selection for VOUCHER sales
    if (_saleType == 'VOUCHER' && _selectedVoucher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or scan a voucher'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if walk-in or client needs to be created
    Client? clientForSale;

    if (_isWalkIn) {
      // Use walk-in customer (no client required)
      clientForSale = null;
    } else if (_showNewClientForm) {
      // Validate new client form
      if (_clientNameController.text.isEmpty ||
          _clientPhoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter client name and phone number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create new client
      final database = ref.read(databaseProvider);
      try {
        final clientId = await database.into(database.clients).insert(
              ClientsCompanion.insert(
                name: _clientNameController.text,
                phone: _clientPhoneController.text,
                siteId: drift.Value(_selectedSite!.id),
                registrationDate: DateTime.now(),
                email: drift.Value(_clientEmailController.text.isEmpty
                    ? null
                    : _clientEmailController.text),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        // Get the newly created client
        clientForSale = await (database.select(database.clients)
              ..where((tbl) => tbl.id.equals(clientId)))
            .getSingle();

        // Reload clients list
        await _loadClients();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating client: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a client, add new client, or choose walk-in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    } else {
      clientForSale = _selectedClient;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final database = ref.read(databaseProvider);
      final repository = SalesRepository(database);
      final voucherService = ref.read(voucherServiceProvider);
      final commissionService = ref.read(commissionServiceProvider);

      // Get current user from database
      final users = await database.select(database.users).get();
      final currentUser = users.first;

      int saleId;

      if (_isWalkIn) {
        // Create sale without client (walk-in)
        final receiptNo = 'WI-${DateTime.now().millisecondsSinceEpoch}';
        saleId = await database.into(database.sales).insert(
              SalesCompanion.insert(
                receiptNumber: receiptNo,
                voucherId: drift.Value(_selectedVoucher?.id),
                agentId: currentUser.id,
                siteId: drift.Value(_selectedSite!.id),
                clientId: drift.Value(null), // Walk-in customer
                amount: double.parse(_amountController.text),
                paymentMethod: _paymentMethod,
                commission: drift.Value(_commissionController.text.isEmpty
                    ? 0
                    : double.parse(_commissionController.text)),
                saleDate: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        // Use makeSale helper which generates receipt number
        saleId = await repository.makeSale(
          voucherId: _selectedVoucher?.id ?? 1,
          agentId: currentUser.id,
          clientId: clientForSale!.id,
          siteId: _selectedSite!.id,
          amount: double.parse(_amountController.text),
          paymentMethod: _paymentMethod,
          commission: _commissionController.text.isEmpty
              ? 0
              : double.parse(_commissionController.text),
        );
      }

      // Mark voucher as sold if it's a voucher sale
      if (_saleType == 'VOUCHER' && _selectedVoucher != null) {
        await voucherService.markVoucherAsSold(
          voucherId: _selectedVoucher!.id,
          soldByUserId: currentUser.id,
        );
      }

      // Calculate commission
      await commissionService.calculateCommission(
        saleId: saleId,
        agentId: currentUser.id,
        saleAmount: double.parse(_amountController.text),
        clientId: clientForSale?.id,
        packageId: _selectedPackage?.id,
      );

      if (!mounted) return;

      // Show success with option to send SMS
      final shouldSendSms = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sale Completed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_showNewClientForm
                  ? 'Sale recorded and client added successfully!'
                  : 'Sale recorded successfully!'),
              if (_saleType == 'VOUCHER' && _selectedVoucher != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Voucher Details:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText('Code: ${_selectedVoucher!.code}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 18)),
                if (_selectedVoucher!.validity != null)
                  Text('Validity: ${_selectedVoucher!.validity}'),
                if (_selectedVoucher!.speed != null)
                  Text('Speed: ${_selectedVoucher!.speed}'),
                const SizedBox(height: 16),
                if (clientForSale != null)
                  const Text('Send voucher code via SMS to client?'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            if (_saleType == 'VOUCHER' && clientForSale != null)
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.sms),
                label: const Text('Send SMS'),
              ),
          ],
        ),
      );

      if (!mounted) return;

      // Send SMS if requested
      if (shouldSendSms == true &&
          clientForSale != null &&
          _selectedVoucher != null) {
        await _sendVoucherSms(clientForSale, _selectedVoucher!);
      }

      if (!mounted) return;

      // Reset form to allow another sale
      _resetForm();

      // Show a snackbar confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sale completed! Ready for next transaction.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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

  Future<void> _sendVoucherSms(Client client, Voucher voucher) async {
    try {
      final database = ref.read(databaseProvider);

      // Format SMS message
      final message = '''
Hello ${client.name},

Thank you for your purchase!

Voucher Code: ${voucher.code}
${voucher.validity != null ? 'Validity: ${voucher.validity}' : ''}
${voucher.speed != null ? 'Speed: ${voucher.speed}' : ''}

Use this code to connect to our network.

Thank you!
''';

      // Log SMS
      await database.into(database.smsLogs).insert(
            SmsLogsCompanion.insert(
              recipient: client.phone,
              message: message,
              status: 'PENDING',
              type: 'NOTIFICATION',
              sentAt: drift.Value(DateTime.now()),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Voucher sent to ${client.phone}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SMS: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _resetForm() {
    if (mounted) {
      setState(() {
        _selectedClient = null;
        _selectedVoucher = null;
        _selectedPackage = null;
        _amountController.clear();
        _commissionController.clear();
        _searchController.clear();
        _voucherCodeController.clear();
        _clientNameController.clear();
        _clientPhoneController.clear();
        _clientEmailController.clear();
        _paymentMethod = 'CASH';
        _saleType = 'VOUCHER';
        _isWalkIn = false;
        _showNewClientForm = false;
      });
    }
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Customer Information',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('Walk-in'),
                              selected: _isWalkIn,
                              onSelected: (selected) {
                                setState(() {
                                  _isWalkIn = selected;
                                  if (selected) {
                                    _selectedClient = null;
                                    _showNewClientForm = false;
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            if (!_isWalkIn)
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showNewClientForm = !_showNewClientForm;
                                    if (_showNewClientForm) {
                                      _selectedClient = null;
                                    }
                                  });
                                },
                                icon: Icon(_showNewClientForm
                                    ? Icons.close
                                    : Icons.person_add),
                                label: Text(_showNewClientForm
                                    ? 'Cancel'
                                    : 'New Client'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      _showNewClientForm ? Colors.red : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isWalkIn)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sale will be recorded without customer details',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_showNewClientForm)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client Name *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _clientNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter client name',
                              prefixIcon: const Icon(Icons.person),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Phone Number *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _clientPhoneController,
                            decoration: InputDecoration(
                              hintText: '+255 XXX XXX XXX',
                              prefixIcon: const Icon(Icons.phone),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Email (Optional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _clientEmailController,
                            decoration: InputDecoration(
                              hintText: 'client@example.com',
                              prefixIcon: const Icon(Icons.email),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search existing client',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedClient != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Text(
                                    _selectedClient!.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(_selectedClient!.name),
                                subtitle: Text(_selectedClient!.phone),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _selectedClient = null),
                                ),
                              ),
                            )
                          else if (_searchController.text.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _getFilteredClients().isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('No clients found'),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _getFilteredClients().length,
                                      itemBuilder: (context, index) {
                                        final client =
                                            _getFilteredClients()[index];
                                        return ListTile(
                                          leading: CircleAvatar(
                                              child: Text(client.name[0]
                                                  .toUpperCase())),
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
                    DropdownButtonFormField<Site>(
                      initialValue: _selectedSite,
                      decoration: const InputDecoration(
                        labelText: 'Site *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: _sites.map((site) {
                        return DropdownMenuItem<Site>(
                          value: site,
                          child: Text(site.name),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedSite = value),
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a site';
                        }
                        return null;
                      },
                    ),
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
                      onChanged: (value) {
                        setState(() {
                          _saleType = value!;
                          if (_saleType == 'VOUCHER') {
                            _loadAvailableVouchers();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Voucher Selection (only show for VOUCHER sales)
                    if (_saleType == 'VOUCHER') ...[
                      Card(
                        color: Colors.blue.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.confirmation_number,
                                      color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Voucher Selection',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Package filter (optional)
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Filter by Package (Optional)',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                initialValue: _selectedPackage?.id,
                                items: _packages
                                    .map((pkg) => DropdownMenuItem(
                                          value: pkg.id,
                                          child: Text(
                                              '${pkg.name} - ${CurrencyFormatter.format(pkg.price)}'),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPackage = _packages
                                        .firstWhere((p) => p.id == value);
                                    _loadAvailableVouchers(packageId: value);
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Scan or Enter Code
                              TextField(
                                controller: _voucherCodeController,
                                decoration: InputDecoration(
                                  labelText: 'Scan or Enter Voucher Code',
                                  hintText: 'e.g., 645827',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(Icons.qr_code_scanner),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () {
                                      _searchVoucherByCode(
                                          _voucherCodeController.text);
                                    },
                                  ),
                                ),
                                onSubmitted: (value) {
                                  _searchVoucherByCode(value);
                                },
                              ),
                              const SizedBox(height: 16),

                              // Or select from dropdown
                              const Text('Or select from available vouchers:',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Available Vouchers',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                initialValue: _selectedVoucher?.id,
                                items: _availableVouchers
                                    .map((voucher) => DropdownMenuItem(
                                          value: voucher.id,
                                          child: Text(
                                            '${voucher.code}${voucher.price != null ? ' - ${CurrencyFormatter.format(voucher.price!)}' : ''}',
                                            style: const TextStyle(
                                                fontFamily: 'monospace'),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVoucher = _availableVouchers
                                        .firstWhere((v) => v.id == value);
                                    _voucherCodeController.text =
                                        _selectedVoucher!.code;
                                    if (_selectedVoucher!.price != null) {
                                      _amountController.text =
                                          _selectedVoucher!.price.toString();
                                    }
                                  });
                                },
                              ),

                              // Selected voucher details
                              if (_selectedVoucher != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.green, size: 20),
                                          const SizedBox(width: 8),
                                          const Text('Selected Voucher:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Code: ${_selectedVoucher!.code}',
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 16)),
                                      if (_selectedVoucher!.validity != null)
                                        Text(
                                            'Validity: ${_selectedVoucher!.validity}'),
                                      if (_selectedVoucher!.speed != null)
                                        Text(
                                            'Speed: ${_selectedVoucher!.speed}'),
                                      if (_selectedVoucher!.price != null)
                                        Text(
                                            'Price: ${CurrencyFormatter.format(_selectedVoucher!.price!)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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

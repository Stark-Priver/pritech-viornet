import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';

class CommissionSettingsScreen extends ConsumerStatefulWidget {
  const CommissionSettingsScreen({super.key});

  @override
  ConsumerState<CommissionSettingsScreen> createState() =>
      _CommissionSettingsScreenState();
}

class _CommissionSettingsScreenState
    extends ConsumerState<CommissionSettingsScreen> {
  int _rebuildKey = 0;

  void _refresh() {
    setState(() {
      _rebuildKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userRoles = authState.userRoles;
    final db = ref.watch(databaseProvider);

    // Check if user has permission (SUPER_ADMIN or FINANCE)
    final hasPermission = userRoles.any((role) =>
        role == 'SUPER_ADMIN' || role == 'ADMIN' || role == 'FINANCE');

    if (!hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Commission Settings')),
        body: const Center(
          child: Text('You do not have permission to manage commissions'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCommissionDialog(context, db),
          ),
        ],
      ),
      body: FutureBuilder<List<CommissionSetting>>(
        key: ValueKey(_rebuildKey),
        future: db.getAllCommissionSettings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading commission settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final settings = snapshot.data ?? [];

          if (settings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.percent, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No commission rules configured',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCommissionDialog(context, db),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Commission Rule'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: settings.length,
            itemBuilder: (context, index) {
              final setting = settings[index];
              return _buildCommissionCard(context, db, setting);
            },
          );
        },
      ),
    );
  }

  Widget _buildCommissionCard(
      BuildContext context, SupabaseDataService db, CommissionSetting setting) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: setting.isActive ? Colors.green : Colors.grey[300],
          child: Icon(
            setting.isActive ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
          ),
        ),
        title: Text(
          setting.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(setting.description ?? ''),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(_getCommissionTypeLabel(setting.commissionType)),
                  backgroundColor: Colors.blue[100],
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                Chip(
                  label: Text(_getApplicableToLabel(setting.applicableTo)),
                  backgroundColor: Colors.orange[100],
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                Chip(
                  label: Text('Priority: ${setting.priority}'),
                  backgroundColor: Colors.purple[100],
                  labelStyle: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Rate: ${_formatRate(setting.commissionType, setting.rate)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: setting.isActive,
              onChanged: (value) => _toggleActive(db, setting, value),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditCommissionDialog(context, db, setting);
                } else if (value == 'delete') {
                  _deleteCommission(context, db, setting);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _getCommissionTypeLabel(String type) {
    switch (type) {
      case 'PERCENTAGE':
        return 'Percentage';
      case 'FIXED_AMOUNT':
        return 'Fixed Amount';
      case 'TIERED':
        return 'Tiered';
      default:
        return type;
    }
  }

  String _getApplicableToLabel(String applicableTo) {
    switch (applicableTo) {
      case 'ALL_AGENTS':
        return 'All Agents';
      case 'SPECIFIC_ROLE':
        return 'Specific Role';
      case 'SPECIFIC_USER':
        return 'Specific User';
      case 'SPECIFIC_CLIENT':
        return 'Specific Client';
      case 'SPECIFIC_PACKAGE':
        return 'Specific Package';
      default:
        return applicableTo;
    }
  }

  String _formatRate(String type, double rate) {
    if (type == 'PERCENTAGE') {
      return '$rate%';
    } else {
      return 'TZS ${rate.toStringAsFixed(0)}';
    }
  }

  void _toggleActive(
      SupabaseDataService db, CommissionSetting setting, bool value) {
    db.updateCommissionSetting(setting.id, {'is_active': value});
    _refresh();
  }

  void _showAddCommissionDialog(BuildContext context, SupabaseDataService db) {
    showDialog(
      context: context,
      builder: (context) => CommissionDialog(db: db),
    ).then((_) => _refresh());
  }

  void _showEditCommissionDialog(
      BuildContext context, SupabaseDataService db, CommissionSetting setting) {
    showDialog(
      context: context,
      builder: (context) => CommissionDialog(db: db, setting: setting),
    ).then((_) => _refresh());
  }

  void _deleteCommission(
      BuildContext context, SupabaseDataService db, CommissionSetting setting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Commission Rule'),
        content: Text('Are you sure you want to delete "${setting.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              db.deleteCommissionSetting(setting.id);
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class CommissionDialog extends StatefulWidget {
  final SupabaseDataService db;
  final CommissionSetting? setting;

  const CommissionDialog({
    super.key,
    required this.db,
    this.setting,
  });

  @override
  State<CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends State<CommissionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _rateController;
  late TextEditingController _minSaleController;
  late TextEditingController _maxSaleController;
  late TextEditingController _priorityController;

  String _commissionType = 'PERCENTAGE';
  String _applicableTo = 'ALL_AGENTS';
  int? _selectedRoleId;
  int? _selectedUserId;
  int? _selectedClientId;
  int? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.setting?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.setting?.description ?? '');
    _rateController =
        TextEditingController(text: widget.setting?.rate.toString() ?? '10');
    _minSaleController = TextEditingController(
        text: widget.setting?.minSaleAmount.toString() ?? '0');
    _maxSaleController =
        TextEditingController(text: widget.setting?.maxSaleAmount?.toString());
    _priorityController =
        TextEditingController(text: widget.setting?.priority.toString() ?? '1');

    if (widget.setting != null) {
      _commissionType = widget.setting!.commissionType;
      _applicableTo = widget.setting!.applicableTo;
      _selectedRoleId = widget.setting!.roleId;
      _selectedUserId = widget.setting!.userId;
      _selectedClientId = widget.setting!.clientId;
      _selectedPackageId = widget.setting!.packageId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _minSaleController.dispose();
    _maxSaleController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.setting == null
          ? 'Add Commission Rule'
          : 'Edit Commission Rule'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Rule Name *',
                  hintText: 'e.g., Standard Commission',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _commissionType,
                decoration: const InputDecoration(labelText: 'Commission Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'PERCENTAGE', child: Text('Percentage')),
                  DropdownMenuItem(
                      value: 'FIXED_AMOUNT', child: Text('Fixed Amount')),
                ],
                onChanged: (value) =>
                    setState(() => _commissionType = value ?? 'PERCENTAGE'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateController,
                decoration: InputDecoration(
                  labelText: _commissionType == 'PERCENTAGE'
                      ? 'Rate (%) *'
                      : 'Fixed Amount (TZS) *',
                  hintText: _commissionType == 'PERCENTAGE' ? '10' : '5000',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Rate is required';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minSaleController,
                      decoration: const InputDecoration(
                        labelText: 'Min Sale Amount',
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxSaleController,
                      decoration: const InputDecoration(
                        labelText: 'Max Sale Amount',
                        hintText: 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _applicableTo,
                decoration: const InputDecoration(labelText: 'Applicable To'),
                items: const [
                  DropdownMenuItem(
                      value: 'ALL_AGENTS', child: Text('All Agents')),
                  DropdownMenuItem(
                      value: 'SPECIFIC_ROLE', child: Text('Specific Role')),
                  DropdownMenuItem(
                      value: 'SPECIFIC_USER', child: Text('Specific User')),
                  DropdownMenuItem(
                      value: 'SPECIFIC_CLIENT', child: Text('Specific Client')),
                  DropdownMenuItem(
                      value: 'SPECIFIC_PACKAGE',
                      child: Text('Specific Package')),
                ],
                onChanged: (value) =>
                    setState(() => _applicableTo = value ?? 'ALL_AGENTS'),
              ),
              const SizedBox(height: 12),
              // Show specific user dropdown
              if (_applicableTo == 'SPECIFIC_USER')
                FutureBuilder<List<AppUser>>(
                  future: widget.db.getAllUsers(),
                  builder: (context, snapshot) {
                    final users = snapshot.data ?? [];
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Select Agent/User',
                      ),
                      items: users
                          .map((user) => DropdownMenuItem(
                                value: user.id,
                                child: Text('${user.name} (${user.role})'),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedUserId = value),
                      validator: (value) =>
                          value == null ? 'Please select a user' : null,
                    );
                  },
                ),
              // Show specific package dropdown
              if (_applicableTo == 'SPECIFIC_PACKAGE')
                FutureBuilder<List<Package>>(
                  future: widget.db.getAllPackages(),
                  builder: (context, snapshot) {
                    final packages = snapshot.data ?? [];
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedPackageId,
                      decoration: const InputDecoration(
                        labelText: 'Select Package',
                      ),
                      items: packages
                          .map((pkg) => DropdownMenuItem(
                                value: pkg.id,
                                child:
                                    Text('${pkg.name} - ${pkg.duration} days'),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedPackageId = value),
                      validator: (value) =>
                          value == null ? 'Please select a package' : null,
                    );
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priorityController,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  hintText: 'Higher = applies first',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveCommission,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveCommission() {
    if (!_formKey.currentState!.validate()) return;

    final fields = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'commission_type': _commissionType,
      'rate': double.parse(_rateController.text),
      'min_sale_amount': double.parse(_minSaleController.text),
      'max_sale_amount': _maxSaleController.text.isEmpty
          ? null
          : double.parse(_maxSaleController.text),
      'applicable_to': _applicableTo,
      'role_id': _selectedRoleId,
      'user_id': _selectedUserId,
      'client_id': _selectedClientId,
      'package_id': _selectedPackageId,
      'priority': int.parse(_priorityController.text),
      'start_date': widget.setting?.startDate.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'is_active': true,
    };

    if (widget.setting == null) {
      widget.db.createCommissionSetting(fields);
    } else {
      widget.db.updateCommissionSetting(widget.setting!.id, fields);
    }

    Navigator.pop(context);
  }
}

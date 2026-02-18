import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/sms_manager_service.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});

  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _contactFilter = 'All';
  int? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Send SMS'),
            Tab(text: 'Templates'),
            Tab(text: 'Contacts'),
            Tab(text: 'SMS Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendSmsTab(),
          _buildTemplatesTab(),
          _buildContactsTab(),
          _buildSmsLogsTab(),
        ],
      ),
    );
  }

  Widget _buildSendSmsTab() {
    return const SendSmsScreen();
  }

  Widget _buildTemplatesTab() {
    final database = ref.watch(databaseProvider);

    return FutureBuilder<List<SmsTemplate>>(
      future: database.select(database.smsTemplates).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final templates = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${templates.length} Templates',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTemplateDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Template'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: templates.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No SMS templates found'),
                          SizedBox(height: 8),
                          Text('Create templates for quick SMS sending',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(template.name[0].toUpperCase()),
                            ),
                            title: Text(template.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  template.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.label_outline,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      template.type,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      template.isActive
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 14,
                                      color: template.isActive
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      template.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: template.isActive
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'use',
                                  child: Row(
                                    children: [
                                      Icon(Icons.send),
                                      SizedBox(width: 8),
                                      Text('Use Template'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'use') {
                                  _useTemplate(template);
                                } else if (value == 'edit') {
                                  _showEditTemplateDialog(template);
                                } else if (value == 'delete') {
                                  _deleteTemplate(template);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmsLogsTab() {
    final database = ref.watch(databaseProvider);

    return FutureBuilder<List<SmsLog>>(
      future: _getSmsLogs(database),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(child: Text('No SMS logs found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      _getStatusColor(log.status).withValues(alpha: 0.2),
                  child: Icon(
                    _getStatusIcon(log.status),
                    color: _getStatusColor(log.status),
                  ),
                ),
                title: Text(log.recipient),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.status,
                      style: TextStyle(
                        color: _getStatusColor(log.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SENT':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'SENT':
        return Icons.check_circle;
      case 'PENDING':
        return Icons.schedule;
      case 'FAILED':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Widget _buildContactsTab() {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('Active'),
                      _buildFilterChip('Expiring Soon'),
                      _buildFilterChip('Inactive'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Site>>(
                  future: database.select(database.sites).get(),
                  builder: (context, snapshot) {
                    final sites = snapshot.data ?? [];
                    if (sites.isEmpty) return const SizedBox();

                    return DropdownButtonFormField<int?>(
                      initialValue: _selectedSiteId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Site',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All Sites')),
                        ...sites.map((site) => DropdownMenuItem(
                              value: site.id,
                              child: Text(site.name),
                            )),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedSiteId = value),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // Contacts List
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: _getFilteredContacts(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = snapshot.data ?? [];
                if (contacts.isEmpty) {
                  return const Center(child: Text('No contacts found'));
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${contacts.length} contacts',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _sendBulkSmsToFiltered(contacts),
                            icon: const Icon(Icons.send),
                            label: const Text('Send to Selected'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: contact.isActive
                                    ? Colors.green
                                    : Colors.grey,
                                child: Text(
                                  contact.name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(contact.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(contact.phone),
                                  if (contact.expiryDate != null)
                                    Text(
                                      'Expires: ${_formatDate(contact.expiryDate!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: () => _sendSmsToContact(contact),
                              ),
                              isThreeLine: contact.expiryDate != null,
                            ),
                          );
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
        onPressed: () => _addNewContact(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _contactFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _contactFilter = label;
          });
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<List<Client>> _getFilteredContacts(AppDatabase database) async {
    var query = database.select(database.clients);

    // Filter by site if selected
    if (_selectedSiteId != null) {
      query.where((tbl) => tbl.siteId.equals(_selectedSiteId!));
    }

    final allClients = await query.get();

    // Apply status filter
    var filteredClients = allClients;
    if (_contactFilter == 'Active') {
      filteredClients = allClients.where((client) {
        return client.isActive &&
            (client.expiryDate?.isAfter(DateTime.now()) ?? false);
      }).toList();
    } else if (_contactFilter == 'Inactive') {
      filteredClients = allClients.where((client) {
        return !client.isActive ||
            (client.expiryDate != null &&
                client.expiryDate!.isBefore(DateTime.now()));
      }).toList();
    } else if (_contactFilter == 'Expiring Soon') {
      final now = DateTime.now();
      final sevenDaysFromNow = now.add(const Duration(days: 7));
      filteredClients = allClients.where((client) {
        if (client.expiryDate == null || !client.isActive) return false;
        return client.expiryDate!.isAfter(now) &&
            client.expiryDate!.isBefore(sevenDaysFromNow);
      }).toList();
    }

    return filteredClients;
  }

  Future<void> _sendSmsToContact(Client contact) async {
    final messageController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send SMS to ${contact.name}'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(labelText: 'Message'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isNotEmpty) {
                final database = ref.read(databaseProvider);
                final messenger = ScaffoldMessenger.of(context);
                await database.into(database.smsLogs).insert(
                      SmsLogsCompanion.insert(
                        recipient: contact.phone,
                        message: messageController.text,
                        status: 'PENDING',
                        type: 'MANUAL',
                        clientId: Value(contact.id),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('SMS queued for sending'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBulkSmsToFiltered(List<Client> contacts) async {
    final messageController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send to ${contacts.length} contacts'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(labelText: 'Message'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isNotEmpty) {
                final database = ref.read(databaseProvider);
                final messenger = ScaffoldMessenger.of(context);
                for (final contact in contacts) {
                  await database.into(database.smsLogs).insert(
                        SmsLogsCompanion.insert(
                          recipient: contact.phone,
                          message: messageController.text,
                          status: 'PENDING',
                          type: 'MARKETING',
                          clientId: Value(contact.id),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  setState(() {});
                  messenger.showSnackBar(
                    SnackBar(
                      content:
                          Text('${contacts.length} SMS queued for sending'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewContact() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    final messenger = ScaffoldMessenger.of(context);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final database = ref.read(databaseProvider);
                await database.into(database.clients).insert(
                      ClientsCompanion.insert(
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        email: emailController.text.trim().isEmpty
                            ? const Value.absent()
                            : Value(emailController.text.trim()),
                        address: addressController.text.trim().isEmpty
                            ? const Value.absent()
                            : Value(addressController.text.trim()),
                        registrationDate: DateTime.now(),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  setState(() {});
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Contact added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<List<SmsLog>> _getSmsLogs(AppDatabase database) async {
    return await (database.select(database.smsLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  void _useTemplate(SmsTemplate template) {
    _tabController.animateTo(0); // Switch to Send SMS tab
    // In a real implementation, you'd populate the message field
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using template: ${template.name}')),
    );
  }

  void _showAddTemplateDialog() {
    final nameController = TextEditingController();
    final messageController = TextEditingController();
    final typeController = TextEditingController(text: 'General');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add SMS Template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Welcome, Reminder, Promotion',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                return;
              }

              final database = ref.read(databaseProvider);
              await database.into(database.smsTemplates).insert(
                    SmsTemplatesCompanion.insert(
                      name: nameController.text.trim(),
                      message: messageController.text.trim(),
                      type: typeController.text.trim(),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Template added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateDialog(SmsTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final messageController = TextEditingController(text: template.message);
    final typeController = TextEditingController(text: template.type);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit SMS Template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                return;
              }

              final database = ref.read(databaseProvider);
              await (database.update(database.smsTemplates)
                    ..where((tbl) => tbl.id.equals(template.id)))
                  .write(
                SmsTemplatesCompanion(
                  name: Value(nameController.text.trim()),
                  message: Value(messageController.text.trim()),
                  type: Value(typeController.text.trim()),
                  updatedAt: Value(DateTime.now()),
                  isSynced: const Value(false),
                ),
              );

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Template updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(SmsTemplate template) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final database = ref.read(databaseProvider);
              await (database.delete(database.smsTemplates)
                    ..where((tbl) => tbl.id.equals(template.id)))
                  .go();

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Template deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Professional Send SMS Screen
class SendSmsScreen extends ConsumerStatefulWidget {
  const SendSmsScreen({super.key});

  @override
  ConsumerState<SendSmsScreen> createState() => _SendSmsScreenState();
}

class _SendSmsScreenState extends ConsumerState<SendSmsScreen> {
  String _sendMode = 'manual'; // 'manual' or 'client'
  Client? _selectedClient;
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _permissionsGranted = false;
  bool _checkingPermissions = true;
  List<SimCard> _simCards = [];
  SimCard? _selectedSimCard;

  @override
  void initState() {
    super.initState();
    _initializePermissionsAndSim();
  }

  Future<void> _initializePermissionsAndSim() async {
    try {
      final smsManager = SmsManagerService();

      // Check permissions
      final hasPermissions = await smsManager.hasSmsPermissions();

      if (mounted) {
        setState(() {
          _permissionsGranted = hasPermissions;
          _checkingPermissions = false;
        });
      }

      // Get SIM cards if permissions granted
      if (hasPermissions) {
        final simCards = await smsManager.getAvailableSimCards();
        if (mounted) {
          setState(() {
            _simCards = simCards;
            _selectedSimCard = simCards.isNotEmpty ? simCards.first : null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingPermissions = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final smsManager = SmsManagerService();
      final granted = await smsManager.requestSmsPermissions();

      if (mounted) {
        setState(() => _permissionsGranted = granted);

        if (granted) {
          // Get SIM cards after permissions granted
          final simCards = await smsManager.getAvailableSimCards();
          if (mounted) {
            setState(() {
              _simCards = simCards;
              _selectedSimCard = simCards.isNotEmpty ? simCards.first : null;
            });
          }
          _showSuccess('Permissions granted successfully!');
        } else {
          _showError('SMS permissions are required to send messages');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error requesting permissions: $e');
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sms,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send SMS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose recipient and compose message',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Permission Status
          if (_checkingPermissions)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Checking permissions...',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            )
          else if (!_permissionsGranted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'SMS permissions required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This app needs SMS permissions to send messages. Please grant the required permissions to continue.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestPermissions,
                      icon: const Icon(Icons.check),
                      label: const Text('Grant Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SMS permissions granted',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // SIM Card Selection
          if (_permissionsGranted) ...[
            _buildSectionHeader('SIM Card', Icons.sim_card),
            const SizedBox(height: 12),
            if (_simCards.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text(
                  'No SIM cards detected',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<SimCard>(
                  value: _selectedSimCard,
                  isExpanded: true,
                  underline: const SizedBox(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: _simCards.map((sim) {
                    return DropdownMenuItem(
                      value: sim,
                      child: Row(
                        children: [
                          Icon(
                            Icons.sim_card,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  sim.displayName ?? 'SIM ${sim.slotId + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (sim.phoneNumber != null)
                                  Text(
                                    sim.phoneNumber!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (sim) {
                    if (sim != null) {
                      setState(() => _selectedSimCard = sim);
                    }
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Send Mode Selection
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    'Manual Phone',
                    'manual',
                    Icons.phone,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    'Select Client',
                    'client',
                    Icons.person,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recipient Section
          _buildSectionHeader('Recipient', Icons.person_outline),
          const SizedBox(height: 12),
          if (_sendMode == 'manual') ...[
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: '+255 or 0...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: _phoneController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _phoneController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
            ),
          ] else ...[
            FutureBuilder<List<Client>>(
              future: database.select(database.clients).get(),
              builder: (context, snapshot) {
                final clients = snapshot.data ?? [];
                return DropdownButtonFormField<Client?>(
                  initialValue: _selectedClient,
                  decoration: InputDecoration(
                    labelText: 'Select Client *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Choose a client...'),
                    ),
                    ...clients.map((client) => DropdownMenuItem(
                          value: client,
                          child: Row(
                            children: [
                              Text(client.name),
                              const SizedBox(width: 8),
                              Text(
                                client.phone,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedClient = value);
                  },
                );
              },
            ),
            if (_selectedClient != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedClient!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _selectedClient!.phone,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),

          // Message Section
          _buildSectionHeader('Message', Icons.message_outlined),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Message *',
              hintText: 'Type your SMS message here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.edit),
              counterText: '${_messageController.text.length}/160',
            ),
            maxLines: 5,
            maxLength: 160,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // Character Count
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Characters: ${_messageController.text.length}/160',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_messageController.text.length > 160)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Message too long',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Send Button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _sendSms,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Send SMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cancel Button
          OutlinedButton(
            onPressed: _isLoading ? null : _clearForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: const Text('Clear'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _sendMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _sendMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _sendSms() async {
    // Validation
    String? phone;
    int? clientId;

    if (_sendMode == 'manual') {
      phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        _showError('Please enter a phone number');
        return;
      }
    } else {
      if (_selectedClient == null) {
        _showError('Please select a client');
        return;
      }
      phone = _selectedClient!.phone;
      clientId = _selectedClient!.id;
    }

    if (_messageController.text.trim().isEmpty) {
      _showError('Please enter a message');
      return;
    }

    if (_messageController.text.length > 160) {
      _showError('Message is too long (max 160 characters)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final database = ref.read(databaseProvider);
      await database.into(database.smsLogs).insert(
            SmsLogsCompanion.insert(
              recipient: phone,
              message: _messageController.text.trim(),
              status: 'PENDING',
              type: _sendMode == 'manual' ? 'MANUAL' : 'NOTIFICATION',
              clientId:
                  clientId != null ? Value(clientId) : const Value.absent(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        _showSuccess('SMS queued for sending successfully!');
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error sending SMS: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _phoneController.clear();
    _messageController.clear();
    _selectedClient = null;
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

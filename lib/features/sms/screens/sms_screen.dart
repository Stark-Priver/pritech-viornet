import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';

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
    final messageController = TextEditingController();
    final phoneController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.message),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _sendSms(phoneController.text, messageController.text),
                  icon: const Icon(Icons.send),
                  label: const Text('Send SMS'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendBulkSms(),
                  icon: const Icon(Icons.people),
                  label: const Text('Send to All Clients'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _sendSms(String phone, String message) async {
    if (phone.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final database = ref.read(databaseProvider);
    await database.into(database.smsLogs).insert(
          SmsLogsCompanion.insert(
            recipient: phone,
            message: message,
            status: 'PENDING',
            type: 'NOTIFICATION',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS queued for sending'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
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

  Future<void> _sendBulkSms() async {
    final database = ref.read(databaseProvider);
    final clients = await database.select(database.clients).get();

    final messageController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send to ${clients.length} clients'),
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
                final messenger = ScaffoldMessenger.of(context);
                for (final client in clients) {
                  await database.into(database.smsLogs).insert(
                        SmsLogsCompanion.insert(
                          recipient: client.phone,
                          message: messageController.text,
                          status: 'PENDING',
                          type: 'MARKETING',
                          clientId: Value(client.id),
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
                      content: Text('${clients.length} SMS queued for sending'),
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

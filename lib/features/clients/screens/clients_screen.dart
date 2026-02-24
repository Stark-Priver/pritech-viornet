import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';
import 'add_edit_client_screen.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  int _rebuildKey = 0;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    final authState = ref.watch(authProvider);
    final canManage = authState.userRoles
        .any((r) => r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'FINANCE');

    return Scaffold(
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search clients...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('Active'),
                      _buildFilterChip('Inactive'),
                      _buildFilterChip('Expiring Soon'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Clients List
          Expanded(
            child: FutureBuilder<List<Client>>(
              key: ValueKey(_rebuildKey),
              future: _getFilteredClients(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final clients = snapshot.data ?? [];

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No clients found',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first client to get started',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _rebuildKey++;
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return _buildClientCard(client, database, canManage);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEditClientScreen(),
                  ),
                );
                if (result == true) {
                  setState(() {
                    _rebuildKey++;
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Client'),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Future<void> _confirmDeleteClient(
      SupabaseDataService db, Client client) async {
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
          const Text('Delete Client',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to permanently delete this client?'),
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
                  Text(client.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(client.phone),
                  if (client.email != null) Text(client.email!),
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
      await db.deleteClient(client.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Client deleted'), backgroundColor: Color(0xFF10B981)));
      setState(() => _rebuildKey++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _statusFilter = label;
            _rebuildKey++;
          });
        },
      ),
    );
  }

  Widget _buildClientCard(
      Client client, SupabaseDataService database, bool canManage) {
    final isActive = client.isActive &&
        (client.expiryDate?.isAfter(DateTime.now()) ?? false);
    final daysUntilExpiry = client.expiryDate != null
        ? client.expiryDate!.difference(DateTime.now()).inDays
        : 0;
    final isExpiringSoon = daysUntilExpiry <= 7 && daysUntilExpiry > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/clients/${client.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isActive ? Colors.green : Colors.grey,
                    child: Text(
                      client.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          client.phone,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isExpiringSoon ? Colors.orange : Colors.green)
                              : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isActive
                              ? (isExpiringSoon ? 'Expiring Soon' : 'Active')
                              : 'Inactive',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (client.address != null)
                    Expanded(
                        child:
                            _buildInfoItem(Icons.location_on, client.address!)),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Expires: ${_formatDate(client.expiryDate)}',
                    ),
                  ),
                ],
              ),
              if (client.email != null) ...[
                const SizedBox(height: 8),
                _buildInfoItem(Icons.email, client.email!),
              ],
              if (canManage) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditClientScreen(client: client),
                          ),
                        );
                        if (result == true) setState(() => _rebuildKey++);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteClient(database, client),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No expiry';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<List<Client>> _getFilteredClients(SupabaseDataService database) async {
    final authNotifier = ref.read(authProvider.notifier);
    final canAccessAllSites = authNotifier.canAccessAllSites;
    final currentUser = authNotifier.currentUser;

    // Admin / Finance / Super-Admin → every client.
    // All other roles → only clients they registered OR were assigned to them.
    List<Client> allClients;
    if (canAccessAllSites) {
      allClients = await database.getAllClients();
    } else {
      if (currentUser == null) return [];
      allClients = await database.getClientsByUser(currentUser.id);
    }

    // Apply search filter first if needed
    var clients = allClients;
    if (_searchQuery.isNotEmpty) {
      clients = clients.where((client) {
        return client.name.toLowerCase().contains(_searchQuery) ||
            client.phone.contains(_searchQuery) ||
            (client.email?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter == 'Active') {
      return clients.where((client) {
        return client.isActive &&
            (client.expiryDate?.isAfter(DateTime.now()) ?? false);
      }).toList();
    } else if (_statusFilter == 'Inactive') {
      return clients.where((client) {
        return !client.isActive ||
            (client.expiryDate != null &&
                client.expiryDate!.isBefore(DateTime.now()));
      }).toList();
    } else if (_statusFilter == 'Expiring Soon') {
      final now = DateTime.now();
      final sevenDaysFromNow = now.add(const Duration(days: 7));
      return clients.where((client) {
        if (client.expiryDate == null || !client.isActive) return false;
        return client.expiryDate!.isAfter(now) &&
            client.expiryDate!.isBefore(sevenDaysFromNow);
      }).toList();
    }

    return clients;
  }
}

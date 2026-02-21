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
                      return _buildClientCard(client);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      ),
    );
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

  Widget _buildClientCard(Client client) {
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
    final userSites = authNotifier.currentUserSites;

    // Fetch all clients then filter by site access
    List<Client> allClients;
    if (!canAccessAllSites && userSites.isEmpty) {
      return [];
    }

    allClients = await database.getAllClients();

    if (!canAccessAllSites && userSites.isNotEmpty) {
      allClients =
          allClients.where((c) => userSites.contains(c.siteId)).toList();
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

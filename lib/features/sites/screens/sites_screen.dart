import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';
import 'add_edit_site_screen.dart';
import 'site_isp_subscription_screen.dart';

class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditSiteScreen(),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search sites...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Site>>(
              future: _getFilteredSites(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final sites = snapshot.data ?? [];

                if (sites.isEmpty) {
                  return const Center(
                    child: Text('No sites found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sites.length,
                    itemBuilder: (context, index) {
                      final site = sites[index];
                      return _buildSiteCard(site);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(Site site) {
    final database = ref.read(databaseProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SiteIspSubscriptionScreen(site: site),
            ),
          ).then((_) => setState(() {}));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: site.isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: site.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (site.location != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            site.location!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: site.isActive ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      site.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (site.contactPerson != null || site.contactPhone != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (site.contactPerson != null)
                      Expanded(
                        child:
                            _buildInfoItem(Icons.person, site.contactPerson!),
                      ),
                    if (site.contactPhone != null)
                      Expanded(
                        child: _buildInfoItem(Icons.phone, site.contactPhone!),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FutureBuilder<int>(
                    future: _getSiteTeamCount(database, site.id),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return TextButton.icon(
                        onPressed: () {
                          _showManageTeamDialog(site);
                        },
                        icon: const Icon(Icons.group, size: 18),
                        label: Text('Team Members ($count)'),
                      );
                    },
                  ),
                ],
              ),
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

  Future<List<Site>> _getFilteredSites(AppDatabase database) async {
    final authNotifier = ref.read(authProvider.notifier);
    final canAccessAllSites = authNotifier.canAccessAllSites;
    final userSites = authNotifier.currentUserSites;

    List<Site> allSites;

    if (!canAccessAllSites && userSites.isNotEmpty) {
      // Filter to only show assigned sites
      allSites = await (database.select(database.sites)
            ..where((tbl) => tbl.id.isIn(userSites)))
          .get();
    } else if (!canAccessAllSites && userSites.isEmpty) {
      // User has no assigned sites
      return [];
    } else {
      // User can see all sites
      allSites = await database.select(database.sites).get();
    }

    if (_searchQuery.isEmpty) {
      return allSites;
    }

    return allSites.where((site) {
      return site.name.toLowerCase().contains(_searchQuery) ||
          (site.location?.toLowerCase().contains(_searchQuery) ?? false) ||
          (site.contactPerson?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  Future<int> _getSiteTeamCount(AppDatabase database, int siteId) async {
    final results = await (database.select(database.userSites)
          ..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
    return results.length;
  }

  void _showManageTeamDialog(Site site) {
    showDialog(
      context: context,
      builder: (context) => _ManageTeamDialog(site: site),
    ).then((_) => setState(() {}));
  }
}

class _ManageTeamDialog extends ConsumerStatefulWidget {
  final Site site;

  const _ManageTeamDialog({required this.site});

  @override
  ConsumerState<_ManageTeamDialog> createState() => _ManageTeamDialogState();
}

class _ManageTeamDialogState extends ConsumerState<_ManageTeamDialog> {
  List<int> _assignedUserIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedUsers();
  }

  Future<void> _loadAssignedUsers() async {
    final database = ref.read(databaseProvider);
    final userSites = await (database.select(database.userSites)
          ..where((tbl) => tbl.siteId.equals(widget.site.id)))
        .get();
    setState(() {
      _assignedUserIds = userSites.map((us) => us.userId).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage Team - ${widget.site.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child: FutureBuilder<List<User>>(
                  future: database.select(database.users).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isAssigned = _assignedUserIds.contains(user.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: isAssigned,
                            onChanged: (value) {
                              _toggleUserAssignment(user.id, value ?? false);
                            },
                            title: Text(user.name),
                            subtitle: Text('${user.email} • ${user.role}'),
                            secondary: CircleAvatar(
                              backgroundColor: Colors.blue[700],
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserAssignment(int userId, bool assign) async {
    final database = ref.read(databaseProvider);

    try {
      if (assign) {
        // Assign user to site
        await database.into(database.userSites).insert(
              UserSitesCompanion.insert(
                userId: userId,
                siteId: widget.site.id,
                assignedAt: DateTime.now(),
              ),
            );
        setState(() {
          _assignedUserIds.add(userId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User assigned to site')),
          );
        }
      } else {
        // Remove user from site
        final deleteQuery = database.delete(database.userSites);
        deleteQuery.where((tbl) =>
            tbl.userId.equals(userId) & tbl.siteId.equals(widget.site.id));
        await deleteQuery.go();
        setState(() {
          _assignedUserIds.remove(userId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User removed from site')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

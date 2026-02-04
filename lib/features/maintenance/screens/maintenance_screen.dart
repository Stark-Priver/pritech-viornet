import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../repository/maintenance_repository.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';
  int? _selectedSiteId;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    final repository = MaintenanceRepository(database);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Management'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ALL', child: Text('All Status')),
              const PopupMenuItem(value: 'PENDING', child: Text('Pending')),
              const PopupMenuItem(
                value: 'IN_PROGRESS',
                child: Text('In Progress'),
              ),
              const PopupMenuItem(value: 'COMPLETED', child: Text('Completed')),
              const PopupMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<MaintenanceData>>(
              future: _getFilteredMaintenance(repository),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final maintenances = snapshot.data ?? [];

                if (maintenances.isEmpty) {
                  return const Center(
                    child: Text('No maintenance records found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: maintenances.length,
                    itemBuilder: (context, index) {
                      return _buildMaintenanceCard(
                        context,
                        maintenances[index],
                        repository,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMaintenanceDialog(context, repository),
        icon: const Icon(Icons.add),
        label: const Text('Report Issue'),
      ),
    );
  }

  Widget _buildFilterBar() {
    final database = ref.watch(databaseProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Priority', _priorityFilter == 'ALL', () {
                  setState(() => _priorityFilter = 'ALL');
                }),
                _buildFilterChip('Low', _priorityFilter == 'LOW', () {
                  setState(() => _priorityFilter = 'LOW');
                }),
                _buildFilterChip('Medium', _priorityFilter == 'MEDIUM', () {
                  setState(() => _priorityFilter = 'MEDIUM');
                }),
                _buildFilterChip('High', _priorityFilter == 'HIGH', () {
                  setState(() => _priorityFilter = 'HIGH');
                }),
                _buildFilterChip('Critical', _priorityFilter == 'CRITICAL', () {
                  setState(() => _priorityFilter = 'CRITICAL');
                }),
                const SizedBox(width: 8),
                FutureBuilder<List<Site>>(
                  future: database.select(database.sites).get(),
                  builder: (context, snapshot) {
                    final sites = snapshot.data ?? [];
                    if (sites.isEmpty) return const SizedBox.shrink();

                    return DropdownButton<int?>(
                      value: _selectedSiteId,
                      hint: const Text('Filter by Site'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Sites'),
                        ),
                        ...sites.map((site) {
                          return DropdownMenuItem(
                            value: site.id,
                            child: Text(site.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSiteId = value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Future<List<MaintenanceData>> _getFilteredMaintenance(
    MaintenanceRepository repository,
  ) async {
    List<MaintenanceData> maintenances;

    if (_statusFilter == 'ALL') {
      maintenances = await repository.getAllMaintenance();
    } else {
      maintenances = await repository.getMaintenanceByStatus(_statusFilter);
    }

    // Filter by priority
    if (_priorityFilter != 'ALL') {
      maintenances =
          maintenances.where((m) => m.priority == _priorityFilter).toList();
    }

    // Filter by site
    if (_selectedSiteId != null) {
      maintenances =
          maintenances.where((m) => m.siteId == _selectedSiteId).toList();
    }

    // Sort by reported date (newest first)
    maintenances.sort((a, b) => b.reportedDate.compareTo(a.reportedDate));

    return maintenances;
  }

  Widget _buildMaintenanceCard(
    BuildContext context,
    MaintenanceData maintenance,
    MaintenanceRepository repository,
  ) {
    final database = ref.watch(databaseProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(context, maintenance, repository),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      maintenance.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildStatusChip(maintenance.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                maintenance.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.priority_high,
                    maintenance.priority,
                    _getPriorityColor(maintenance.priority),
                  ),
                  if (maintenance.siteId != null)
                    FutureBuilder<Site?>(
                      future: (database.select(database.sites)
                            ..where(
                                (tbl) => tbl.id.equals(maintenance.siteId!)))
                          .getSingleOrNull(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return _buildInfoChip(
                            Icons.location_on,
                            snapshot.data!.name,
                            Colors.blue,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  _buildInfoChip(
                    Icons.calendar_today,
                    DateFormat('MMM dd, yyyy').format(maintenance.reportedDate),
                    Colors.grey,
                  ),
                  if (maintenance.cost != null)
                    _buildInfoChip(
                      Icons.attach_money,
                      'TSh ${maintenance.cost!.toStringAsFixed(0)}',
                      Colors.green,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        break;
      case 'COMPLETED':
        color = Colors.green;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.deepOrange;
      case 'CRITICAL':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAddMaintenanceDialog(
    BuildContext context,
    MaintenanceRepository repository,
  ) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final notesController = TextEditingController();
    String priority = 'MEDIUM';
    int? selectedSiteId;
    int? selectedAssetId;
    DateTime? scheduledDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Maintenance Issue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => priority = value!);
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Site>>(
                  future: ref
                      .read(databaseProvider)
                      .select(
                        ref.read(databaseProvider).sites,
                      )
                      .get(),
                  builder: (context, snapshot) {
                    final sites = snapshot.data ?? [];
                    return DropdownButtonFormField<int?>(
                      initialValue: selectedSiteId,
                      decoration: const InputDecoration(
                        labelText: 'Site (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ...sites.map((site) => DropdownMenuItem(
                              value: site.id,
                              child: Text(site.name),
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedSiteId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (selectedSiteId != null)
                  FutureBuilder<List<Asset>>(
                    future: (ref.read(databaseProvider).select(
                              ref.read(databaseProvider).assets,
                            )
                          ..where((tbl) => tbl.siteId.equals(selectedSiteId!)))
                        .get(),
                    builder: (context, snapshot) {
                      final assets = snapshot.data ?? [];
                      if (assets.isEmpty) return const SizedBox.shrink();

                      return DropdownButtonFormField<int?>(
                        initialValue: selectedAssetId,
                        decoration: const InputDecoration(
                          labelText: 'Asset (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          ...assets.map((asset) => DropdownMenuItem(
                                value: asset.id,
                                child: Text(asset.name),
                              )),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedAssetId = value);
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    scheduledDate == null
                        ? 'Schedule Date (Optional)'
                        : 'Scheduled: ${DateFormat('MMM dd, yyyy').format(scheduledDate!)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => scheduledDate = date);
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    descriptionController.text.isEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in required fields'),
                    ),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);

                final users = await ref
                    .read(databaseProvider)
                    .select(ref.read(databaseProvider).users)
                    .get();
                final currentUser = users.first;

                final maintenance = MaintenanceCompanion(
                  title: drift.Value(titleController.text),
                  description: drift.Value(descriptionController.text),
                  priority: drift.Value(priority),
                  status: const drift.Value('PENDING'),
                  siteId: drift.Value(selectedSiteId),
                  assetId: drift.Value(selectedAssetId),
                  reportedBy: drift.Value(currentUser.id),
                  reportedDate: drift.Value(DateTime.now()),
                  scheduledDate: drift.Value(scheduledDate),
                  notes: drift.Value(notesController.text.isEmpty
                      ? null
                      : notesController.text),
                  createdAt: drift.Value(DateTime.now()),
                  updatedAt: drift.Value(DateTime.now()),
                );

                await repository.createMaintenance(maintenance);

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Maintenance issue reported successfully'),
                  ),
                );
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDetails(
    BuildContext context,
    MaintenanceData maintenance,
    MaintenanceRepository repository,
  ) {
    final database = ref.watch(databaseProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(maintenance.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', maintenance.status),
              _buildDetailRow('Priority', maintenance.priority),
              const Divider(),
              _buildDetailRow('Description', maintenance.description),
              if (maintenance.siteId != null)
                FutureBuilder<Site?>(
                  future: (database.select(database.sites)
                        ..where((tbl) => tbl.id.equals(maintenance.siteId!)))
                      .getSingleOrNull(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return _buildDetailRow('Site', snapshot.data!.name);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              _buildDetailRow(
                'Reported Date',
                DateFormat('MMM dd, yyyy HH:mm')
                    .format(maintenance.reportedDate),
              ),
              if (maintenance.scheduledDate != null)
                _buildDetailRow(
                  'Scheduled Date',
                  DateFormat('MMM dd, yyyy').format(maintenance.scheduledDate!),
                ),
              if (maintenance.completedDate != null)
                _buildDetailRow(
                  'Completed Date',
                  DateFormat('MMM dd, yyyy HH:mm')
                      .format(maintenance.completedDate!),
                ),
              if (maintenance.cost != null)
                _buildDetailRow(
                  'Cost',
                  'TSh ${maintenance.cost!.toStringAsFixed(2)}',
                ),
              if (maintenance.resolution != null)
                _buildDetailRow('Resolution', maintenance.resolution!),
              if (maintenance.notes != null)
                _buildDetailRow('Notes', maintenance.notes!),
            ],
          ),
        ),
        actions: [
          if (maintenance.status != 'COMPLETED' &&
              maintenance.status != 'CANCELLED')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showUpdateStatusDialog(context, maintenance, repository);
              },
              child: const Text('Update Status'),
            ),
          if (maintenance.status == 'PENDING' ||
              maintenance.status == 'IN_PROGRESS')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCompleteMaintenanceDialog(
                  context,
                  maintenance,
                  repository,
                );
              },
              child: const Text('Complete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  void _showUpdateStatusDialog(
    BuildContext context,
    MaintenanceData maintenance,
    MaintenanceRepository repository,
  ) {
    String newStatus = maintenance.status;
    int? assignedTo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: newStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: ['PENDING', 'IN_PROGRESS', 'CANCELLED']
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' ')),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => newStatus = value!);
                },
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<User>>(
                future: ref
                    .read(databaseProvider)
                    .select(
                      ref.read(databaseProvider).users,
                    )
                    .get(),
                builder: (context, snapshot) {
                  final users = snapshot.data ?? [];
                  return DropdownButtonFormField<int?>(
                    initialValue: assignedTo ?? maintenance.assignedTo,
                    decoration: const InputDecoration(
                      labelText: 'Assign To (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None'),
                      ),
                      ...users.map((user) => DropdownMenuItem(
                            value: user.id,
                            child: Text(user.name),
                          )),
                    ],
                    onChanged: (value) {
                      setDialogState(() => assignedTo = value);
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);

                await repository.updateMaintenance(
                  maintenance.id,
                  MaintenanceCompanion(
                    status: drift.Value(newStatus),
                    assignedTo: drift.Value(assignedTo),
                  ),
                );

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Status updated successfully')),
                );
                setState(() {});
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompleteMaintenanceDialog(
    BuildContext context,
    MaintenanceData maintenance,
    MaintenanceRepository repository,
  ) {
    final resolutionController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Maintenance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: resolutionController,
              decoration: const InputDecoration(
                labelText: 'Resolution',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              decoration: const InputDecoration(
                labelText: 'Cost (TSh)',
                border: OutlineInputBorder(),
                prefixText: 'TSh ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (resolutionController.text.isEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter resolution')),
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);

              final cost = costController.text.isEmpty
                  ? null
                  : double.tryParse(costController.text);

              await repository.completeMaintenance(
                maintenance.id,
                resolutionController.text,
                cost,
              );

              nav.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Maintenance completed successfully'),
                ),
              );
              setState(() {});
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}

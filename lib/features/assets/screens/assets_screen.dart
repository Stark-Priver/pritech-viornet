import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  String _typeFilter = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAssetDialog(database),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search assets...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('ROUTER'),
                _buildFilterChip('AP'),
                _buildFilterChip('SWITCH'),
                _buildFilterChip('UPS'),
                _buildFilterChip('OTHER'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Asset>>(
              future: _getFilteredAssets(database),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final assets = snapshot.data ?? [];
                if (assets.isEmpty) {
                  return const Center(child: Text('No assets found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: assets.length,
                  itemBuilder: (context, index) =>
                      _buildAssetCard(assets[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _typeFilter == label,
        onSelected: (selected) => setState(() => _typeFilter = label),
      ),
    );
  }

  Widget _buildAssetCard(Asset asset) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(_getAssetIcon(asset.type), color: Colors.blue),
        title: Text(asset.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${asset.type} • ${asset.condition}'),
            if (asset.serialNumber != null) Text('SN: ${asset.serialNumber}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: asset.isActive ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            asset.isActive ? 'Active' : 'Inactive',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getAssetIcon(String type) {
    switch (type) {
      case 'ROUTER':
        return Icons.router;
      case 'AP':
        return Icons.wifi;
      case 'SWITCH':
        return Icons.device_hub;
      case 'UPS':
        return Icons.battery_charging_full;
      default:
        return Icons.devices;
    }
  }

  Future<List<Asset>> _getFilteredAssets(AppDatabase database) async {
    final allAssets = await database.select(database.assets).get();
    var assets = allAssets;

    if (_typeFilter != 'All') {
      assets = assets.where((a) => a.type == _typeFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      assets = assets.where((a) {
        return a.name.toLowerCase().contains(_searchQuery) ||
            (a.serialNumber?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    return assets;
  }

  Future<void> _showAddAssetDialog(AppDatabase database) async {
    final nameController = TextEditingController();
    final serialController = TextEditingController();
    String type = 'ROUTER';
    String condition = 'GOOD';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Asset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Asset Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['ROUTER', 'AP', 'SWITCH', 'UPS', 'CABLE', 'OTHER']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serialController,
                  decoration: const InputDecoration(labelText: 'Serial Number'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: condition,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: ['NEW', 'GOOD', 'FAIR', 'POOR', 'DAMAGED']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => condition = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await database.into(database.assets).insert(
                        AssetsCompanion.insert(
                          name: nameController.text,
                          type: type,
                          serialNumber: serialController.text.isEmpty
                              ? const Value.absent()
                              : Value(serialController.text),
                          condition: condition,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    this.setState(() {});
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';

class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  int _rebuildKey = 0;

  @override
  void initState() {
    super.initState();
    _initializeDefaultPackages();
  }

  Future<void> _initializeDefaultPackages() async {
    final database = ref.read(databaseProvider);
    final existingPackages = await database.select(database.packages).get();

    // Only create defaults if no packages exist
    if (existingPackages.isEmpty) {
      final defaultPackages = [
        PackagesCompanion.insert(
          name: '1 Week',
          duration: 7,
          price: 5000.0,
          description: drift.Value('Access for 7 days'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PackagesCompanion.insert(
          name: '2 Weeks',
          duration: 14,
          price: 9000.0,
          description: drift.Value('Access for 14 days'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PackagesCompanion.insert(
          name: '1 Month',
          duration: 30,
          price: 15000.0,
          description: drift.Value('Access for 30 days'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PackagesCompanion.insert(
          name: '3 Months',
          duration: 90,
          price: 40000.0,
          description: drift.Value('Access for 3 months'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final package in defaultPackages) {
        await database.into(database.packages).insert(package);
      }

      if (mounted) {
        setState(() {
          _rebuildKey++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Management'),
      ),
      body: FutureBuilder<List<Package>>(
        key: ValueKey(_rebuildKey),
        future: database.select(database.packages).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return const Center(child: Text('No packages found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final package = packages[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        package.isActive ? Colors.green : Colors.grey,
                    child: const Icon(
                      Icons.wifi,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    package.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration: ${package.duration} days'),
                      if (package.description != null)
                        Text(package.description!),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(package.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: package.isActive
                              ? Colors.green[100]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          package.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            color: package.isActive
                                ? Colors.green[900]
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _editPackage(package),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPackage(),
        icon: const Icon(Icons.add),
        label: const Text('Add Package'),
      ),
    );
  }

  Future<void> _addPackage() async {
    final nameController = TextEditingController();
    final durationController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Add New Package',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Package Name *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., 1 Week, 1 Month',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Duration (days) *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationController,
                  decoration: InputDecoration(
                    hintText: '7, 30, 90',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Price (TSh) *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    hintText: '15000',
                    prefixText: 'TSh ',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Package description',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  durationController.text.isEmpty ||
                  priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (nameController.text.isNotEmpty &&
                  durationController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                final database = ref.read(databaseProvider);
                await database.into(database.packages).insert(
                  PackagesCompanion.insert(
                    name: nameController.text.trim(),
                    duration: int.parse(durationController.text.trim()),
                    price: double.parse(priceController.text.trim()),
                    description: drift.Value(descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim()),
                    isActive: const drift.Value(true),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
                
                if (!mounted) return;
                setState(() {
                  _rebuildKey++;
                });
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        const Text('Package added successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Add Package'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPackage(Package package) async {
    final nameController = TextEditingController(text: package.name);
    final durationController =
        TextEditingController(text: package.duration.toString());
    final priceController =
        TextEditingController(text: package.price.toString());
    final descriptionController =
        TextEditingController(text: package.description ?? '');
    bool isActive = package.isActive;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Edit Package',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Package Name *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Duration (days) *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Price (TSh) *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      prefixText: 'TSh ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Active Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isActive ? 'Package is active' : 'Package is inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Delete package
                showDialog(
                  context: dialogContext,
                  builder: (ctx) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        const Text('Delete Package'),
                      ],
                    ),
                    content: const Text(
                      'Are you sure you want to delete this package? This action cannot be undone.',
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final database = ref.read(databaseProvider);
                          await (database.delete(database.packages)
                                ..where((tbl) => tbl.id.equals(package.id)))
                              .go();

                          if (!mounted) return;
                          setState(() {
                            _rebuildKey++;
                          });
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.delete,
                                      color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Text('Package deleted successfully'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    durationController.text.isEmpty ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (nameController.text.isNotEmpty &&
                    durationController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  final database = ref.read(databaseProvider);
                  await (database.update(database.packages)
                        ..where((tbl) => tbl.id.equals(package.id)))
                      .write(
                    PackagesCompanion(
                      name: drift.Value(nameController.text.trim()),
                      duration: drift.Value(
                          int.parse(durationController.text.trim())),
                      price: drift.Value(
                          double.parse(priceController.text.trim())),
                      description: drift.Value(
                          descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim()),
                      isActive: drift.Value(isActive),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );

                  if (!mounted) return;
                  setState(() {
                    _rebuildKey++;
                  });
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          const Text('Package updated successfully'),
                        ],
                        ),
                        backgroundColor: Colors.green,
                        ),
                  );
                }
              },
              child: const Text('Update Package'),
            ),
          ],
        ),
      ),
    );
  }
}


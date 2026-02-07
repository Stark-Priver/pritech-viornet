import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';

class VoucherManagementScreen extends ConsumerStatefulWidget {
  const VoucherManagementScreen({super.key});

  @override
  ConsumerState<VoucherManagementScreen> createState() =>
      _VoucherManagementScreenState();
}

class _VoucherManagementScreenState
    extends ConsumerState<VoucherManagementScreen> {
  String _statusFilter = 'ALL';
  int _rebuildKey = 0;

  void _refresh() {
    setState(() {
      _rebuildKey++;
    });
  }

  Future<List<Voucher>> _loadVouchers() async {
    final voucherService = ref.read(voucherServiceProvider);
    final vouchers = await voucherService
        .watchVouchers(
          status: _statusFilter == 'ALL' ? null : _statusFilter,
        )
        .first;
    return vouchers;
  }

  Future<void> _showAddVoucherDialog() async {
    final codeController = TextEditingController();
    final priceController = TextEditingController();
    final validityController = TextEditingController();
    final speedController = TextEditingController();
    int? selectedPackageId;

    final packages = await ref
        .read(databaseProvider)
        .select(ref.read(databaseProvider).packages)
        .get();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Voucher'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Voucher Code',
                  hintText: 'e.g., 645827',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration:
                    const InputDecoration(labelText: 'Package (Optional)'),
                items: packages
                    .map((pkg) => DropdownMenuItem(
                          value: pkg.id,
                          child: Text(pkg.name),
                        ))
                    .toList(),
                onChanged: (value) => selectedPackageId = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (Optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: validityController,
                decoration: const InputDecoration(
                  labelText: 'Validity (Optional)',
                  hintText: 'e.g., 12Hours, 1Day',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: speedController,
                decoration: const InputDecoration(
                  labelText: 'Speed (Optional)',
                  hintText: 'e.g., 5Mbps',
                ),
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
              if (codeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter voucher code')),
                );
                return;
              }

              final voucherService = ref.read(voucherServiceProvider);

              try {
                await voucherService.addVoucher(
                  code: codeController.text,
                  packageId: selectedPackageId,
                  price: double.tryParse(priceController.text),
                  validity: validityController.text.isNotEmpty
                      ? validityController.text
                      : null,
                  speed: speedController.text.isNotEmpty
                      ? speedController.text
                      : null,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voucher added successfully')),
                  );
                  _refresh();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
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

  Future<void> _showBulkUploadDialog() async {
    int? selectedPackageId;
    final packages = await ref
        .read(databaseProvider)
        .select(ref.read(databaseProvider).packages)
        .get();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Bulk Upload Vouchers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Upload Mikrotik HTML voucher file'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration:
                    const InputDecoration(labelText: 'Package (Optional)'),
                initialValue: selectedPackageId,
                items: packages
                    .map((pkg) => DropdownMenuItem(
                          value: pkg.id,
                          child: Text(pkg.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedPackageId = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['html', 'htm'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final htmlContent = await file.readAsString();

                  if (mounted) {
                    Navigator.pop(context);

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Uploading vouchers...'),
                          ],
                        ),
                      ),
                    );

                    final voucherService = ref.read(voucherServiceProvider);
                    final count = await voucherService.bulkInsertVouchers(
                      htmlContent: htmlContent,
                      packageId: selectedPackageId,
                    );

                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('$count vouchers uploaded successfully')),
                      );
                      _refresh();
                    }
                  }
                }
              },
              child: const Text('Select File'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
                _refresh();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ALL', child: Text('All')),
              const PopupMenuItem(value: 'AVAILABLE', child: Text('Available')),
              const PopupMenuItem(value: 'SOLD', child: Text('Sold')),
              const PopupMenuItem(value: 'USED', child: Text('Used')),
              const PopupMenuItem(value: 'EXPIRED', child: Text('Expired')),
            ],
            child: Chip(
              label: Text(_statusFilter),
              avatar: const Icon(Icons.filter_list, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          FutureBuilder<Map<String, int>>(
            key: ValueKey(_rebuildKey),
            future: ref.read(voucherServiceProvider).getVoucherStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              final stats = snapshot.data!;
              return Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Total',
                        value: stats['total']!,
                        color: Colors.blue,
                      ),
                      _StatItem(
                        label: 'Available',
                        value: stats['available']!,
                        color: Colors.green,
                      ),
                      _StatItem(
                        label: 'Sold',
                        value: stats['sold']!,
                        color: Colors.orange,
                      ),
                      _StatItem(
                        label: 'Used',
                        value: stats['used']!,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Voucher List
          Expanded(
            child: FutureBuilder<List<Voucher>>(
              key: ValueKey(_rebuildKey),
              future: _loadVouchers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        ElevatedButton(
                          onPressed: _refresh,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final vouchers = snapshot.data ?? [];

                if (vouchers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _statusFilter == 'ALL'
                              ? 'No vouchers yet'
                              : 'No $_statusFilter vouchers',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text('Upload vouchers to get started'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: vouchers.length,
                  itemBuilder: (context, index) {
                    final voucher = vouchers[index];
                    return _VoucherListItem(
                      voucher: voucher,
                      onRefresh: _refresh,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _showBulkUploadDialog,
            icon: const Icon(Icons.upload_file),
            label: const Text('Bulk Upload'),
            heroTag: 'bulk',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _showAddVoucherDialog,
            heroTag: 'add',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _VoucherListItem extends ConsumerWidget {
  final Voucher voucher;
  final VoidCallback onRefresh;

  const _VoucherListItem({
    required this.voucher,
    required this.onRefresh,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'AVAILABLE':
        return Colors.green;
      case 'SOLD':
        return Colors.orange;
      case 'USED':
        return Colors.purple;
      case 'EXPIRED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(voucher.status).withValues(alpha: 0.2),
          child: Text(
            voucher.code.substring(0, 2),
            style: TextStyle(
              color: _getStatusColor(voucher.status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          voucher.code,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (voucher.price != null)
              Text('Price: ${CurrencyFormatter.format(voucher.price!)}'),
            if (voucher.validity != null) Text('Validity: ${voucher.validity}'),
            if (voucher.speed != null) Text('Speed: ${voucher.speed}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            voucher.status,
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: _getStatusColor(voucher.status).withValues(alpha: 0.2),
          side: BorderSide(color: _getStatusColor(voucher.status)),
        ),
        onTap: () {
          // Show voucher details
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Voucher: ${voucher.code}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${voucher.status}'),
                  if (voucher.price != null)
                    Text('Price: ${CurrencyFormatter.format(voucher.price!)}'),
                  if (voucher.validity != null)
                    Text('Validity: ${voucher.validity}'),
                  if (voucher.speed != null) Text('Speed: ${voucher.speed}'),
                  if (voucher.soldAt != null)
                    Text('Sold At: ${voucher.soldAt}'),
                  if (voucher.qrCodeData != null)
                    Text(
                      'QR: ${voucher.qrCodeData}',
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                if (voucher.status == 'AVAILABLE')
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Voucher'),
                          content: const Text(
                              'Are you sure you want to delete this voucher?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(voucherServiceProvider)
                            .deleteVoucher(voucher.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Voucher deleted')),
                        );
                        onRefresh();
                      }
                    },
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

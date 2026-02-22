import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/rbac/permissions.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
bool _canDeleteVouchers(List<String> roles) =>
    roles.any((r) => r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'FINANCE');

bool _canViewSummary(List<String> roles) =>
    roles.any((r) => r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'FINANCE');
// ─────────────────────────────────────────────────────────────────────────────

class VoucherManagementScreen extends ConsumerStatefulWidget {
  const VoucherManagementScreen({super.key});

  @override
  ConsumerState<VoucherManagementScreen> createState() =>
      _VoucherManagementScreenState();
}

class _VoucherManagementScreenState
    extends ConsumerState<VoucherManagementScreen>
    with SingleTickerProviderStateMixin {
  String _statusFilter = 'ALL';
  int? _packageFilter;
  int? _siteFilter;
  String? _batchFilter;
  int _rebuildKey = 0;

  // multi-select
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  // tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _rebuildKey++;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _exitSelection() => setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });

  // ── Bulk delete ──────────────────────────────────────────────────────────
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vouchers'),
        content:
            Text('Delete $count selected voucher${count == 1 ? '' : 's'}?\n'
                'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final progressNotifier = ValueNotifier<(int, int)>((0, count));
    // Capture the dialog navigator BEFORE the async gap so we can close
    // only the dialog (not the whole screen) after deletion finishes.
    NavigatorState? dialogNavigator;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        dialogNavigator = Navigator.of(dlgCtx);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Deleting…'),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progressNotifier,
              builder: (_, v, __) =>
                  LinearProgressIndicator(value: v.$2 > 0 ? v.$1 / v.$2 : 0),
            ),
          ),
        );
      },
    );

    final svc = ref.read(voucherServiceProvider);
    int done = 0;
    for (final id in List<int>.from(_selectedIds)) {
      await svc.deleteVoucher(id);
      done++;
      progressNotifier.value = (done, count);
    }
    if (!mounted) return;
    // Close only the progress dialog using its own navigator.
    if (dialogNavigator != null && dialogNavigator!.canPop()) {
      dialogNavigator!.pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count voucher${count == 1 ? '' : 's'} deleted'),
        backgroundColor: Colors.red));
    _refresh();
  }

  Future<List<Voucher>> _loadVouchers() async {
    final authNotifier = ref.read(authProvider.notifier);
    final canAccessAll = authNotifier.canAccessAllSites;
    final userSites = authNotifier.currentUserSites;

    final voucherService = ref.read(voucherServiceProvider);

    // Determine effective site restriction
    int? effectiveSiteId;
    List<int>? effectiveSiteIds;

    if (!canAccessAll) {
      if (userSites.isEmpty) return []; // not assigned to any site
      if (_siteFilter != null && userSites.contains(_siteFilter)) {
        // user filtered to a specific site within their allowed list
        effectiveSiteId = _siteFilter;
      } else {
        // restrict to all their assigned sites
        effectiveSiteIds = userSites;
      }
    } else {
      // Admin / Finance / Super-Admin: respect manual site filter
      effectiveSiteId = _siteFilter;
    }

    return voucherService.watchVouchers(
      status: _statusFilter == 'ALL' ? null : _statusFilter,
      packageId: _packageFilter,
      siteId: effectiveSiteId,
      siteIds: effectiveSiteIds,
      batchId: _batchFilter,
    );
  }

  Future<void> _showAddVoucherDialog() async {
    final codeController = TextEditingController();
    final priceController = TextEditingController();
    final validityController = TextEditingController();
    final speedController = TextEditingController();
    int? selectedPackageId;
    int? selectedSiteId;

    final packages = await SupabaseDataService().getAllPackages();

    final sites = await SupabaseDataService().getAllSites();

    if (!mounted) return;

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
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Site (Optional)'),
                items: sites
                    .map((site) => DropdownMenuItem(
                          value: site.id,
                          child: Text(site.name),
                        ))
                    .toList(),
                onChanged: (value) => selectedSiteId = value,
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
                  siteId: selectedSiteId,
                  price: double.tryParse(priceController.text),
                  validity: validityController.text.isNotEmpty
                      ? validityController.text
                      : null,
                  speed: speedController.text.isNotEmpty
                      ? speedController.text
                      : null,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voucher added successfully')),
                  );
                  _refresh();
                }
              } catch (e) {
                if (context.mounted) {
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
    int? selectedSiteId;
    final packages = await SupabaseDataService().getAllPackages();
    final sites = await SupabaseDataService().getAllSites();
    if (!mounted) return;

    // ── Step 1: site / package selection ──────────────────────────────────
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          title: const Text('Bulk Upload Vouchers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Upload a Mikrotik HTML voucher file'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Site (Required)'),
                initialValue: selectedSiteId,
                items: sites
                    .map((site) => DropdownMenuItem(
                          value: site.id,
                          child: Text(site.name),
                        ))
                    .toList(),
                onChanged: (v) => setDlgState(() => selectedSiteId = v),
              ),
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
                onChanged: (v) => setDlgState(() => selectedPackageId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedSiteId == null) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('Please select a site first')),
                  );
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('Select File'),
            ),
          ],
        ),
      ),
    );

    if (shouldContinue != true || !mounted) return;

    // ── Step 2: pick file ─────────────────────────────────────────────────
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;

    final String htmlContent;
    try {
      htmlContent = await File(result.files.single.path!).readAsString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error reading file: $e'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (!mounted) return;

    // ── Step 3: progress dialog ───────────────────────────────────────────
    final progressNotifier = ValueNotifier<(int, int)>((0, 0));
    bool cancelled = false;
    NavigatorState? progressDialogNav;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        progressDialogNav = Navigator.of(progressCtx);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Uploading Vouchers'),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progressNotifier,
              builder: (_, progress, __) {
                final done = progress.$1;
                final total = progress.$2;
                final pct = total > 0 ? done / total : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    total == 0
                        ? const LinearProgressIndicator()
                        : LinearProgressIndicator(value: pct),
                    const SizedBox(height: 10),
                    total == 0
                        ? const Text('Parsing file…')
                        : Text(
                            '$done / $total vouchers  •  '
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 13),
                          ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  cancelled = true;
                  Navigator.pop(progressCtx);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    // ── Step 4: run upload ────────────────────────────────────────────────
    try {
      final voucherService = ref.read(voucherServiceProvider);
      final count = await voucherService.bulkInsertVouchers(
        htmlContent: htmlContent,
        packageId: selectedPackageId,
        siteId: selectedSiteId,
        onProgress: (done, total) {
          if (!cancelled) progressNotifier.value = (done, total);
        },
        isCancelled: () => cancelled,
      );

      if (!mounted) return;
      if (!cancelled) {
        if (progressDialogNav != null && progressDialogNav!.canPop()) {
          progressDialogNav!.pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count vouchers uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload cancelled')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!cancelled) {
        if (progressDialogNav != null && progressDialogNav!.canPop()) {
          progressDialogNav!.pop();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading vouchers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFilterDialog() async {
    final packages = await SupabaseDataService().getAllPackages();
    final allSites = await SupabaseDataService().getAllSites();

    // Restrict site list for non-privileged users
    final authNotifier = ref.read(authProvider.notifier);
    final canAccessAll = authNotifier.canAccessAllSites;
    final userSites = authNotifier.currentUserSites;
    final sites = canAccessAll
        ? allSites
        : allSites.where((s) => userSites.contains(s.id)).toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        int? tempPackageFilter = _packageFilter;
        int? tempSiteFilter = _siteFilter;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Filter Vouchers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(labelText: 'Package'),
                  initialValue: tempPackageFilter,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...packages.map((pkg) => DropdownMenuItem(
                          value: pkg.id,
                          child: Text(pkg.name),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => tempPackageFilter = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(labelText: 'Site'),
                  initialValue: tempSiteFilter,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...sites.map((site) => DropdownMenuItem(
                          value: site.id,
                          child: Text(site.name),
                        )),
                  ],
                  onChanged: (value) => setState(() => tempSiteFilter = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  this.setState(() {
                    _packageFilter = null;
                    _siteFilter = null;
                    _batchFilter = null;
                  });
                  Navigator.pop(context);
                  _refresh();
                },
                child: const Text('Clear All'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  this.setState(() {
                    _packageFilter = tempPackageFilter;
                    _siteFilter = tempSiteFilter;
                  });
                  Navigator.pop(context);
                  _refresh();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    // Combine the join-table roles with the direct role field so the check
    // works even when the user_roles table has no rows for this user.
    final userRoles = {
      ...authState.userRoles,
      if (authState.user?.role != null) authState.user!.role,
    }.toList();
    final canDelete = _canDeleteVouchers(userRoles);
    final canSummary = _canViewSummary(userRoles);
    final canCreate = PermissionChecker([authState.user?.role ?? ''])
        .hasPermission(Permissions.createVoucher);
    final canBulkUpload = authState.user?.role == 'SUPER_ADMIN' ||
        authState.user?.role == 'MARKETING' ||
        authState.user?.role == 'ADMIN';

    final vouchersTab = _VouchersTab(
      rebuildKey: _rebuildKey,
      loadVouchers: _loadVouchers,
      selectionMode: _selectionMode,
      selectedIds: _selectedIds,
      canDelete: canDelete,
      onRefresh: _refresh,
      onEnterSelection: (int id) => setState(() {
        _selectionMode = true;
        _selectedIds.add(id); // auto-select the long-pressed item
      }),
      onToggleSelect: (id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
          if (_selectedIds.isEmpty) _selectionMode = false;
        } else {
          _selectedIds.add(id);
        }
      }),
      onSelectAll: (all) => setState(() {
        if (_selectedIds.length == all.length) {
          _selectedIds.clear();
          _selectionMode = false;
        } else {
          _selectedIds
            ..clear()
            ..addAll(all.map((v) => v.id));
        }
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('Voucher Management'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close), onPressed: _exitSelection)
            : null,
        actions: [
          if (_selectionMode && canDelete)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete selected',
              onPressed: _deleteSelected,
            ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: () async {
                final all = await _loadVouchers();
                setState(() {
                  if (_selectedIds.length == all.length) {
                    _selectedIds.clear();
                    _selectionMode = false;
                  } else {
                    _selectedIds
                      ..clear()
                      ..addAll(all.map((v) => v.id));
                  }
                });
              },
            ),
          if (!_selectionMode) ...[
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Select vouchers',
                onPressed: () => setState(() => _selectionMode = true),
              ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            IconButton(
              icon: Badge(
                isLabelVisible: _packageFilter != null || _siteFilter != null,
                child: const Icon(Icons.filter_alt),
              ),
              onPressed: _showFilterDialog,
            ),
            PopupMenuButton<String>(
              onSelected: (v) => setState(() {
                _statusFilter = v;
                _refresh();
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ALL', child: Text('All Status')),
                PopupMenuItem(value: 'AVAILABLE', child: Text('Available')),
                PopupMenuItem(value: 'SOLD', child: Text('Sold')),
                PopupMenuItem(value: 'USED', child: Text('Used')),
                PopupMenuItem(value: 'EXPIRED', child: Text('Expired')),
              ],
              child: Chip(
                label: Text(_statusFilter),
                avatar: const Icon(Icons.assessment, size: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: canSummary
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.receipt_long), text: 'Vouchers'),
                  Tab(icon: Icon(Icons.bar_chart), text: 'Summary'),
                ],
              )
            : null,
      ),
      body: canSummary
          ? TabBarView(
              controller: _tabController,
              children: [
                vouchersTab,
                _SummaryTab(rebuildKey: _rebuildKey),
              ],
            )
          : vouchersTab,
      floatingActionButton: _selectionMode
          ? null
          : (canCreate
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canBulkUpload) ...[
                      FloatingActionButton.extended(
                        onPressed: _showBulkUploadDialog,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Bulk Upload'),
                        heroTag: 'bulk',
                      ),
                      const SizedBox(height: 8),
                    ],
                    FloatingActionButton(
                      onPressed: _showAddVoucherDialog,
                      heroTag: 'add',
                      child: const Icon(Icons.add),
                    ),
                  ],
                )
              : null),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vouchers Tab
// ─────────────────────────────────────────────────────────────────────────────

class _VouchersTab extends StatelessWidget {
  final int rebuildKey;
  final Future<List<Voucher>> Function() loadVouchers;
  final bool selectionMode;
  final Set<int> selectedIds;
  final bool canDelete;
  final VoidCallback onRefresh;
  final void Function(int id) onEnterSelection;
  final void Function(int id) onToggleSelect;
  final void Function(List<Voucher> all) onSelectAll;

  const _VouchersTab({
    required this.rebuildKey,
    required this.loadVouchers,
    required this.selectionMode,
    required this.selectedIds,
    required this.canDelete,
    required this.onRefresh,
    required this.onEnterSelection,
    required this.onToggleSelect,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats row (computed from loaded vouchers)
        FutureBuilder<List<Voucher>>(
          key: ValueKey('stats_$rebuildKey'),
          future: loadVouchers(),
          builder: (_, snap) {
            final vs = snap.data ?? [];
            final av = vs.where((v) => v.status == 'AVAILABLE').length;
            final so = vs.where((v) => v.status == 'SOLD').length;
            final us = vs.where((v) => v.status == 'USED').length;
            return Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                        label: 'Total', value: vs.length, color: Colors.blue),
                    _StatItem(
                        label: 'Available', value: av, color: Colors.green),
                    _StatItem(label: 'Sold', value: so, color: Colors.orange),
                    _StatItem(label: 'Used', value: us, color: Colors.purple),
                  ],
                ),
              ),
            );
          },
        ),

        // Select-all banner
        if (selectionMode)
          FutureBuilder<List<Voucher>>(
            key: ValueKey('banner_$rebuildKey'),
            future: loadVouchers(),
            builder: (ctx, snap) {
              final all = snap.data ?? [];
              final allSel = all.isNotEmpty && selectedIds.length == all.length;
              return Container(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                        value: allSel,
                        tristate: true,
                        onChanged: (_) => onSelectAll(all)),
                    Text(
                        allSel ? 'Deselect all' : 'Select all (${all.length})'),
                  ],
                ),
              );
            },
          ),

        // Voucher list
        Expanded(
          child: FutureBuilder<List<Voucher>>(
            key: ValueKey('list_$rebuildKey'),
            future: loadVouchers(),
            builder: (ctx, snapshot) {
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
                          onPressed: onRefresh, child: const Text('Try Again')),
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
                      const Text('No vouchers found',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Upload vouchers to get started'),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: vouchers.length,
                itemBuilder: (_, i) {
                  final v = vouchers[i];
                  return _VoucherListItem(
                    voucher: v,
                    selectionMode: selectionMode,
                    isSelected: selectedIds.contains(v.id),
                    canDelete: canDelete,
                    onLongPress: onEnterSelection, // void Function(int id)
                    onToggleSelect: () => onToggleSelect(v.id),
                    onRefresh: onRefresh,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Tab  (ADMIN / FINANCE / SUPER_ADMIN)
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  final int rebuildKey;
  const _SummaryTab({required this.rebuildKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Voucher>>(
      key: ValueKey(rebuildKey),
      future: ref.read(voucherServiceProvider).watchVouchers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final vouchers = snapshot.data ?? [];

        // Group by package_id + site_id
        final groups = <String, _GroupStats>{};
        for (final v in vouchers) {
          final key = '${v.packageId ?? 0}_${v.siteId ?? 0}';
          groups.putIfAbsent(
              key,
              () => _GroupStats(
                    packageId: v.packageId,
                    siteId: v.siteId,
                    validity: v.validity,
                    speed: v.speed,
                  ));
          groups[key]!.add(v);
        }
        final sortedGroups = groups.values.toList()
          ..sort((a, b) =>
              (a.packageId ?? 999999).compareTo(b.packageId ?? 999999));

        final grandRevenue = vouchers
            .where((v) => v.status == 'SOLD' || v.status == 'USED')
            .fold<double>(0, (s, v) => s + (v.price ?? 0));
        final grandSold = vouchers.where((v) => v.status == 'SOLD').length;
        final grandAvail =
            vouchers.where((v) => v.status == 'AVAILABLE').length;

        if (sortedGroups.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('No vouchers to summarize',
                    style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Grand totals
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryCell(
                            'Total', '${vouchers.length}', Colors.blue),
                        _SummaryCell('Available', '$grandAvail', Colors.green),
                        _SummaryCell('Sold', '$grandSold', Colors.orange),
                        _SummaryCell(
                            'Revenue',
                            CurrencyFormatter.format(grandRevenue),
                            Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('By Package / Site',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ...sortedGroups.map((g) => _GroupCard(group: g)),
          ],
        );
      },
    );
  }
}

class _GroupStats {
  final int? packageId;
  final int? siteId;
  final String? validity;
  final String? speed;
  int total = 0, available = 0, sold = 0, used = 0;
  double revenue = 0;

  _GroupStats({
    required this.packageId,
    required this.siteId,
    this.validity,
    this.speed,
  });

  void add(Voucher v) {
    total++;
    switch (v.status) {
      case 'AVAILABLE':
        available++;
        break;
      case 'SOLD':
        sold++;
        revenue += v.price ?? 0;
        break;
      case 'USED':
        used++;
        revenue += v.price ?? 0;
        break;
    }
  }
}

class _GroupCard extends ConsumerWidget {
  final _GroupStats group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        group.packageId != null
            ? ref.read(databaseProvider).getPackageById(group.packageId!)
            : Future<Package?>.value(null),
        group.siteId != null
            ? ref.read(databaseProvider).getSiteById(group.siteId!)
            : Future<Site?>.value(null),
      ]),
      builder: (context, snap) {
        final pkg = snap.data != null ? snap.data![0] as Package? : null;
        final site = snap.data != null ? snap.data![1] as Site? : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pkg?.name ?? 'No Package',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    if (site != null)
                      Chip(
                        label: Text(site.name,
                            style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                if (group.validity != null || group.speed != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (group.validity != null) group.validity!,
                      if (group.speed != null) group.speed!,
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryCell('Total', '${group.total}', Colors.blue),
                    _SummaryCell(
                        'Available', '${group.available}', Colors.green),
                    _SummaryCell('Sold', '${group.sold}', Colors.orange),
                    _SummaryCell('Used', '${group.used}', Colors.purple),
                    _SummaryCell('Revenue',
                        CurrencyFormatter.format(group.revenue), Colors.teal),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _VoucherListItem extends ConsumerWidget {
  final Voucher voucher;
  final bool selectionMode;
  final bool isSelected;
  final bool canDelete;
  final void Function(int id) onLongPress;
  final VoidCallback onToggleSelect;
  final VoidCallback onRefresh;

  const _VoucherListItem({
    required this.voucher,
    required this.selectionMode,
    required this.isSelected,
    required this.canDelete,
    required this.onLongPress,
    required this.onToggleSelect,
    required this.onRefresh,
  });

  Color _statusColor(String s) {
    switch (s) {
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
    final color = _statusColor(voucher.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: selectionMode
            ? Checkbox(value: isSelected, onChanged: (_) => onToggleSelect())
            : CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                child: Text(voucher.code.substring(0, 2),
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
        title: Text(voucher.code,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
          label: Text(voucher.status, style: const TextStyle(fontSize: 10)),
          backgroundColor: color.withValues(alpha: 0.15),
          side: BorderSide(color: color),
        ),
        onLongPress: selectionMode ? null : () => onLongPress(voucher.id),
        onTap:
            selectionMode ? onToggleSelect : () => _showDetails(context, ref),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Voucher: ${voucher.code}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Status', voucher.status),
            if (voucher.price != null)
              _DetailRow('Price', CurrencyFormatter.format(voucher.price!)),
            if (voucher.validity != null)
              _DetailRow('Validity', voucher.validity!),
            if (voucher.speed != null) _DetailRow('Speed', voucher.speed!),
            if (voucher.soldAt != null)
              _DetailRow('Sold At', voucher.soldAt.toString()),
            if (voucher.batchId != null) _DetailRow('Batch', voucher.batchId!),
            if (voucher.qrCodeData != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('QR: ${voucher.qrCodeData}',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        actions: [
          if (canDelete && voucher.status == 'AVAILABLE')
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (c2) => AlertDialog(
                    title: const Text('Delete Voucher'),
                    content:
                        const Text('Delete this voucher? Cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c2, false),
                          child: const Text('Cancel')),
                      FilledButton(
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(c2, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(voucherServiceProvider)
                      .deleteVoucher(voucher.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Voucher deleted')));
                    onRefresh();
                  }
                }
              },
              child: const Text('Delete'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 70,
              child: Text('$label:',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

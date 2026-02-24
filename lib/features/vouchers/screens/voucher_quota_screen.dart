import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Voucher Quota Management Screen
// Accessible by ADMIN, FINANCE, SUPER_ADMIN only (enforced via nav + router).
// ─────────────────────────────────────────────────────────────────────────────

class VoucherQuotaScreen extends ConsumerStatefulWidget {
  const VoucherQuotaScreen({super.key});

  @override
  ConsumerState<VoucherQuotaScreen> createState() => _VoucherQuotaScreenState();
}

class _VoucherQuotaScreenState extends ConsumerState<VoucherQuotaScreen> {
  int _rebuildKey = 0;
  String _remittanceFilter = 'PENDING';

  void _refresh() => setState(() => _rebuildKey++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Quota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Settings section ────────────────────────────────────────────
          _QuotaSettingsSection(
            rebuildKey: _rebuildKey,
            onChanged: _refresh,
          ),

          const Divider(height: 1),

          // ── Remittances header + filter ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Agent Remittances',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'PENDING', label: Text('Pending')),
                    ButtonSegment(value: 'ALL', label: Text('All')),
                  ],
                  selected: {_remittanceFilter},
                  onSelectionChanged: (s) =>
                      setState(() => _remittanceFilter = s.first),
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),

          // ── Remittance list ─────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<SalesRemittance>>(
              key: ValueKey('rem_${_rebuildKey}_$_remittanceFilter'),
              future: ref.read(supabaseDataServiceProvider).getAllRemittances(
                    status:
                        _remittanceFilter == 'ALL' ? null : _remittanceFilter,
                  ),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _remittanceFilter == 'PENDING'
                          ? 'No pending remittances'
                          : 'No remittances found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _RemittanceCard(
                    item: items[i],
                    onReviewed: _refresh,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quota Settings Section
// Shows: Global · Per-Site · Per-Package
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaSettingsSection extends ConsumerStatefulWidget {
  const _QuotaSettingsSection(
      {required this.rebuildKey, required this.onChanged});
  final int rebuildKey;
  final VoidCallback onChanged;

  @override
  ConsumerState<_QuotaSettingsSection> createState() =>
      _QuotaSettingsSectionState();
}

class _QuotaSettingsSectionState extends ConsumerState<_QuotaSettingsSection> {
  bool _sitesExpanded = false;
  bool _packagesExpanded = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey('qs_${widget.rebuildKey}'),
      future: Future.wait([
        ref.read(supabaseDataServiceProvider).getAllVoucherQuotaSettings(),
        ref.read(supabaseDataServiceProvider).getAllSites(),
        ref.read(supabaseDataServiceProvider).getAllPackages(),
      ]),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final settings =
            snap.data?.elementAt(0) as List<VoucherQuotaSetting>? ?? [];
        final sites = snap.data?.elementAt(1) as List<Site>? ?? [];
        final packages = snap.data?.elementAt(2) as List<Package>? ?? [];

        // Helpers to find existing settings
        VoucherQuotaSetting forGlobal() => settings.firstWhere(
              (s) => s.siteId == null && s.packageId == null,
              orElse: () => _defaultSetting(siteId: null, packageId: null),
            );

        VoucherQuotaSetting forSite(int siteId) => settings.firstWhere(
              (s) => s.siteId == siteId && s.packageId == null,
              orElse: () => _defaultSetting(siteId: siteId, packageId: null),
            );

        VoucherQuotaSetting forPackage(int packageId) => settings.firstWhere(
              (s) => s.siteId == null && s.packageId == packageId,
              orElse: () => _defaultSetting(siteId: null, packageId: packageId),
            );

        final enabledCount = settings.where((s) => s.isEnabled).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Global ─────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('Global Default',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                '$enabledCount rule${enabledCount == 1 ? '' : 's'} configured',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: _SettingToggleRow(
                setting: forGlobal(),
                onEdit: () => _showEditDialog(
                    ctx, forGlobal(), 'Global Default',
                    onSaved: widget.onChanged),
                onToggle: (v) => _saveSetting(
                  siteId: null,
                  packageId: null,
                  quotaLimit: forGlobal().quotaLimit,
                  isEnabled: v,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            ),

            const Divider(indent: 16, endIndent: 16, height: 1),

            // ── Per-Site ────────────────────────────────────────────────
            ExpansionTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Per Site',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${sites.length} site(s)',
                  style: const TextStyle(fontSize: 11)),
              initiallyExpanded: _sitesExpanded,
              onExpansionChanged: (v) => setState(() => _sitesExpanded = v),
              children: sites.map((site) {
                final s = forSite(site.id);
                return ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(32, 0, 16, 0),
                  title: Text(site.name, style: const TextStyle(fontSize: 13)),
                  subtitle: s.isEnabled
                      ? Text('Limit: ${s.quotaLimit}',
                          style: const TextStyle(fontSize: 11))
                      : const Text('Disabled', style: TextStyle(fontSize: 11)),
                  trailing: _SettingToggleRow(
                    setting: s,
                    onEdit: () => _showEditDialog(ctx, s, site.name,
                        onSaved: widget.onChanged),
                    onToggle: (v) => _saveSetting(
                      siteId: site.id,
                      packageId: null,
                      quotaLimit: s.quotaLimit,
                      isEnabled: v,
                    ),
                  ),
                );
              }).toList(),
            ),

            const Divider(indent: 16, endIndent: 16, height: 1),

            // ── Per-Package ─────────────────────────────────────────────
            ExpansionTile(
              leading: const Icon(Icons.card_giftcard_outlined),
              title: const Text('Per Package',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${packages.length} package(s)',
                  style: const TextStyle(fontSize: 11)),
              initiallyExpanded: _packagesExpanded,
              onExpansionChanged: (v) => setState(() => _packagesExpanded = v),
              children: packages.map((pkg) {
                final s = forPackage(pkg.id);
                return ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(32, 0, 16, 0),
                  title: Text(pkg.name, style: const TextStyle(fontSize: 13)),
                  subtitle: s.isEnabled
                      ? Text('Limit: ${s.quotaLimit}',
                          style: const TextStyle(fontSize: 11))
                      : const Text('Disabled', style: TextStyle(fontSize: 11)),
                  trailing: _SettingToggleRow(
                    setting: s,
                    onEdit: () => _showEditDialog(ctx, s, pkg.name,
                        onSaved: widget.onChanged),
                    onToggle: (v) => _saveSetting(
                      siteId: null,
                      packageId: pkg.id,
                      quotaLimit: s.quotaLimit,
                      isEnabled: v,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  VoucherQuotaSetting _defaultSetting(
          {required int? siteId, required int? packageId}) =>
      VoucherQuotaSetting(
        id: -1,
        siteId: siteId,
        packageId: packageId,
        quotaLimit: 10,
        isEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<void> _saveSetting({
    int? siteId,
    int? packageId,
    required int quotaLimit,
    required bool isEnabled,
  }) async {
    await ref.read(supabaseDataServiceProvider).saveVoucherQuotaSetting(
          siteId: siteId,
          packageId: packageId,
          quotaLimit: quotaLimit,
          isEnabled: isEnabled,
        );
    widget.onChanged();
  }

  void _showEditDialog(
    BuildContext context,
    VoucherQuotaSetting setting,
    String label, {
    required VoidCallback onSaved,
  }) {
    final limitCtrl =
        TextEditingController(text: setting.quotaLimit.toString());
    bool isEnabled = setting.isEnabled;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Quota: $label'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Enable Quota'),
                  value: isEnabled,
                  onChanged: (v) => setSt(() => isEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: limitCtrl,
                  enabled: isEnabled,
                  decoration: const InputDecoration(
                    labelText: 'Max vouchers visible to agents',
                    border: OutlineInputBorder(),
                    suffixText: 'vouchers',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Enter a positive number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref
                    .read(supabaseDataServiceProvider)
                    .saveVoucherQuotaSetting(
                      siteId: setting.siteId,
                      packageId: setting.packageId,
                      quotaLimit: int.parse(limitCtrl.text.trim()),
                      isEnabled: isEnabled,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                onSaved();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small inline toggle+edit row (shared by all setting tiers)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.setting,
    required this.onEdit,
    required this.onToggle,
  });

  final VoucherQuotaSetting setting;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: setting.isEnabled,
          onChanged: onToggle,
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18),
          onPressed: onEdit,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Remittance Card (admin/finance view)
// ─────────────────────────────────────────────────────────────────────────────

class _RemittanceCard extends ConsumerWidget {
  const _RemittanceCard({required this.item, required this.onReviewed});
  final SalesRemittance item;
  final VoidCallback onReviewed;

  static Color _statusColor(String s) {
    switch (s) {
      case 'CONFIRMED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(item.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: FutureBuilder<AppUser?>(
                  future: ref
                      .read(supabaseDataServiceProvider)
                      .getUserById(item.agentId),
                  builder: (_, snap) => Text(
                    snap.data?.name ?? 'Agent #${item.agentId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(item.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.payments_rounded, size: 15),
              const SizedBox(width: 6),
              Text(CurrencyFormatter.format(item.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 16),
              const Icon(Icons.schedule_rounded, size: 15),
              const SizedBox(width: 4),
              Text(
                '${item.submittedAt.day}/${item.submittedAt.month}/${item.submittedAt.year}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ]),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.notes!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            // ── Actions (only for PENDING) ─────────────────────────────
            if (item.status == 'PENDING') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _review(context, ref, 'REJECTED'),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _review(context, ref, 'CONFIRMED'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _review(
      BuildContext context, WidgetRef ref, String newStatus) async {
    final authState = ref.read(authProvider);
    final reviewerId = authState.user?.id;
    if (reviewerId == null) return;
    try {
      await ref.read(supabaseDataServiceProvider).reviewRemittance(
            id: item.id,
            status: newStatus,
            reviewedBy: reviewerId,
          );
      onReviewed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Remittance ${newStatus.toLowerCase()}'),
          backgroundColor: newStatus == 'CONFIRMED' ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

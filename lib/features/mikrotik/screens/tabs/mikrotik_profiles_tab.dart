import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/providers/providers.dart';
import '../../models/mikrotik_models.dart';
import '../../providers/mikrotik_provider.dart';

class MikroTikProfilesTab extends ConsumerStatefulWidget {
  const MikroTikProfilesTab({super.key});

  @override
  ConsumerState<MikroTikProfilesTab> createState() =>
      _MikroTikProfilesTabState();
}

class _MikroTikProfilesTabState extends ConsumerState<MikroTikProfilesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mikrotikProvider.notifier).loadProfiles();
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade700,
      ));
  }

  // ── Add Profile Dialog ─────────────────────────────────────────────────────
  Future<void> _showAddProfileDialog() async {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final sessionCtrl = TextEditingController();
    final sharedCtrl = TextEditingController(text: '1');
    final poolCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Hotspot Profile'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Profile Name *',
                      hintText: 'e.g. 10MB-1Hour',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rate Limit',
                      hintText: 'e.g. 5M/10M  (upload/download)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sessionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Session Timeout',
                      hintText: 'e.g. 01:00:00 or 1d',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sharedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shared Users',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: poolCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address Pool',
                      hintText: 'Optional pool name',
                    ),
                  ),
                ],
              ),
            ),
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
              Navigator.pop(ctx);
              try {
                await ref.read(mikrotikProvider.notifier).addHotspotProfile(
                      name: nameCtrl.text.trim(),
                      rateLimit: rateCtrl.text.trim(),
                      sessionTimeout: sessionCtrl.text.trim(),
                      sharedUsers: sharedCtrl.text.trim().isEmpty
                          ? '1'
                          : sharedCtrl.text.trim(),
                      addressPool: poolCtrl.text.trim(),
                    );
                _showSuccess('Profile "${nameCtrl.text.trim()}" created');
              } catch (e) {
                _showError('Failed: $e');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ── Edit Profile Dialog ────────────────────────────────────────────────────
  Future<void> _showEditDialog(MikroTikHotspotProfile profile) async {
    final rateCtrl = TextEditingController(text: profile.rateLimit);
    final sessionCtrl = TextEditingController(text: profile.sessionTimeout);
    final sharedCtrl = TextEditingController(text: profile.sharedUsers);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit "${profile.name}"'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: rateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rate Limit',
                  hintText: '5M/10M',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sessionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session Timeout',
                  hintText: '01:00:00',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sharedCtrl,
                decoration: const InputDecoration(labelText: 'Shared Users'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              Navigator.pop(ctx);
              try {
                await ref.read(mikrotikProvider.notifier).editHotspotProfile(
                    profile.id,
                    rateLimit: rateCtrl.text.trim(),
                    sessionTimeout: sessionCtrl.text.trim(),
                    sharedUsers: sharedCtrl.text.trim());
                _showSuccess('Profile updated');
              } catch (e) {
                _showError('Failed: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Delete Confirmation ────────────────────────────────────────────────────
  Future<void> _confirmDelete(MikroTikHotspotProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${profile.name}"?'),
        content: profile.userCount > 0
            ? Text(
                'This profile has ${profile.userCount} user(s). '
                'Deleting it may affect those users.',
              )
            : const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(mikrotikProvider.notifier)
            .removeHotspotProfile(profile.id);
        _showSuccess('Profile "${profile.name}" deleted');
      } catch (e) {
        _showError('Failed: $e');
      }
    }
  }

  // ── Generate Vouchers Bottom Sheet ─────────────────────────────────────────
  void _showGenerateSheet(MikroTikHotspotProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _GenerateVouchersSheet(profile: profile),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mikrotikProvider);
    final profiles = state.hotspotProfiles;
    final totalUsers = profiles.fold(0, (s, p) => s + p.userCount);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(mikrotikProvider.notifier).loadProfiles(),
        child: state.isLoading && profiles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ── Stats header ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _StatsHeader(
                      profileCount: profiles.length,
                      totalUsers: totalUsers,
                    ),
                  ),
                  // ── Profile list ──────────────────────────────────────────
                  profiles.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.manage_accounts_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No profiles found',
                                    style: TextStyle(color: Colors.grey)),
                                SizedBox(height: 4),
                                Text('Pull to refresh or add a profile',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _ProfileCard(
                                profile: profiles[i],
                                onEdit: () => _showEditDialog(profiles[i]),
                                onDelete: profiles[i].name == 'default'
                                    ? null
                                    : () => _confirmDelete(profiles[i]),
                                onGenerate: () =>
                                    _showGenerateSheet(profiles[i]),
                              ),
                              childCount: profiles.length,
                            ),
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProfileDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Profile'),
      ),
    );
  }
}

// ── Stats Header ─────────────────────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.profileCount,
    required this.totalUsers,
  });

  final int profileCount;
  final int totalUsers;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
              child: _StatChip(
            icon: Icons.manage_accounts,
            label: 'Profiles',
            value: '$profileCount',
            color: cs.primary,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _StatChip(
            icon: Icons.people,
            label: 'Users',
            value: '$totalUsers',
            color: Colors.teal,
          )),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Card ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onGenerate,
    this.onDelete,
  });

  final MikroTikHotspotProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDefault = profile.name == 'default';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.speed_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (isDefault)
                  Chip(
                    label:
                        const Text('default', style: TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                const SizedBox(width: 4),
                // ── Users badge ─────────────────────────────────────────────
                Chip(
                  avatar: const Icon(Icons.people, size: 14),
                  label: Text(
                    '${profile.userCount} users',
                    style: const TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      profile.userCount > 0 ? cs.primaryContainer : null,
                ),
              ],
            ),

            const Divider(height: 16),

            // ── Detail row ──────────────────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _InfoPill(
                  icon: Icons.swap_vert,
                  label: 'Rate',
                  value: profile.rateLimitDisplay,
                  color: Colors.teal,
                ),
                if (profile.sessionTimeout.isNotEmpty)
                  _InfoPill(
                    icon: Icons.timer_outlined,
                    label: 'Session',
                    value: profile.sessionTimeout,
                    color: Colors.orange,
                  ),
                if (profile.keepaliveTimeout.isNotEmpty)
                  _InfoPill(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Keepalive',
                    value: profile.keepaliveTimeout,
                    color: Colors.pink,
                  ),
                _InfoPill(
                  icon: Icons.share,
                  label: 'Shared',
                  value:
                      profile.sharedUsers.isEmpty ? '1' : profile.sharedUsers,
                  color: Colors.blue,
                ),
                if (profile.addressPool.isNotEmpty)
                  _InfoPill(
                    icon: Icons.lan_outlined,
                    label: 'Pool',
                    value: profile.addressPool,
                    color: Colors.purple,
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Action row ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onGenerate,
                  icon:
                      const Icon(Icons.confirmation_number_outlined, size: 16),
                  label: const Text('Generate Vouchers'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade400,
                    tooltip: 'Delete profile',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Pill ─────────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ── Generate Vouchers Bottom Sheet ────────────────────────────────────────────
class _GenerateVouchersSheet extends ConsumerStatefulWidget {
  const _GenerateVouchersSheet({required this.profile});
  final MikroTikHotspotProfile profile;

  @override
  ConsumerState<_GenerateVouchersSheet> createState() =>
      _GenerateVouchersSheetState();
}

class _GenerateVouchersSheetState
    extends ConsumerState<_GenerateVouchersSheet> {
  final _formKey = GlobalKey<FormState>();
  final _countCtrl = TextEditingController(text: '10');
  final _priceCtrl = TextEditingController();
  final _validityCtrl = TextEditingController();
  final _speedCtrl = TextEditingController();

  int _codeLength = 8;
  Site? _selectedSite;
  List<Site> _sites = [];
  bool _loadingSites = true;

  bool _generating = false;
  int _done = 0;
  int _total = 0;
  VoucherGenerationResult? _result;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final db = ref.read(supabaseDataServiceProvider);
      final sites = await db.getAllSites();
      if (mounted) {
        setState(() {
          _sites = sites;
          _loadingSites = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSites = false);
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    final count = int.tryParse(_countCtrl.text.trim()) ?? 10;
    final price = double.tryParse(_priceCtrl.text.trim());
    final validity =
        _validityCtrl.text.trim().isEmpty ? null : _validityCtrl.text.trim();
    final speed =
        _speedCtrl.text.trim().isEmpty ? null : _speedCtrl.text.trim();

    setState(() {
      _generating = true;
      _done = 0;
      _total = count;
      _result = null;
    });

    try {
      final result =
          await ref.read(mikrotikProvider.notifier).generateBulkVouchers(
                profileName: widget.profile.name,
                count: count,
                codeLength: _codeLength,
                siteId: _selectedSite?.id,
                price: price,
                validity: validity,
                speed: speed,
                onProgress: (done, total) {
                  if (mounted) setState(() => _done = done);
                },
              );
      if (mounted) {
        setState(() {
          _generating = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: _result != null
            ? _buildResult()
            : _generating
                ? _buildProgress()
                : _buildForm(),
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Generate Vouchers — ${widget.profile.name}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            if (widget.profile.rateLimit.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Rate: ${widget.profile.rateLimitDisplay}',
                style: const TextStyle(fontSize: 12, color: Colors.teal),
              ),
            ],

            const Divider(height: 20),

            // Site
            if (_loadingSites)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<Site>(
                initialValue: _selectedSite,
                decoration: const InputDecoration(
                  labelText: 'Site (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('— No site —'),
                  ),
                  ..._sites.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name),
                    ),
                  ),
                ],
                onChanged: (s) => setState(() => _selectedSite = s),
              ),

            const SizedBox(height: 12),

            // Count + code length row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Min 1';
                      if (n > 500) return 'Max 500';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _codeLength,
                    decoration: const InputDecoration(
                      labelText: 'Code Length',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 6, child: Text('6 chars')),
                      DropdownMenuItem(value: 8, child: Text('8 chars')),
                      DropdownMenuItem(value: 10, child: Text('10 chars')),
                      DropdownMenuItem(value: 12, child: Text('12 chars')),
                    ],
                    onChanged: (v) => setState(() => _codeLength = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Price + validity
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _validityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Validity',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: '1d / 1h / 30m',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Speed override
            TextFormField(
              controller: _speedCtrl,
              decoration: const InputDecoration(
                labelText: 'Speed Tag (optional)',
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'e.g. 10Mbps',
                prefixIcon: Icon(Icons.speed),
              ),
            ),

            const SizedBox(height: 20),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.bolt),
                label: Text('Generate ${_countCtrl.text} Vouchers'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Progress ──────────────────────────────────────────────────────────────
  Widget _buildProgress() {
    final pct = _total == 0 ? 0.0 : _done / _total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.confirmation_number_outlined, size: 48),
        const SizedBox(height: 12),
        Text('Generating vouchers…',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('$_done / $_total',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: pct, minHeight: 8),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final allGood = r.failed == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(
          allGood ? Icons.check_circle_outline : Icons.warning_amber_outlined,
          size: 52,
          color: allGood ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 10),
        Text(
          allGood
              ? '${r.succeeded} Vouchers Generated!'
              : '${r.succeeded} succeeded, ${r.failed} failed',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text('Batch ID: ${r.batchId.substring(0, 8)}…',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        if (r.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: r.errors.length,
              itemBuilder: (_, i) => Text(r.errors[i],
                  style: TextStyle(fontSize: 11, color: Colors.red.shade800)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _result = null);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Generate More'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

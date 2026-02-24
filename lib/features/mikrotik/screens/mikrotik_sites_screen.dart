import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';
import '../models/mikrotik_models.dart';
import '../providers/mikrotik_provider.dart';

// ── local provider: loads + caches all sites ─────────────────────────────────
final _mikrotikSitesProvider =
    FutureProvider.autoDispose<List<Site>>((ref) async {
  return ref.read(supabaseDataServiceProvider).getAllSites();
});

// ─────────────────────────────────────────────────────────────────────────────

class MikroTikSitesScreen extends ConsumerStatefulWidget {
  const MikroTikSitesScreen({super.key});

  @override
  ConsumerState<MikroTikSitesScreen> createState() =>
      _MikroTikSitesScreenState();
}

class _MikroTikSitesScreenState extends ConsumerState<MikroTikSitesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(_mikrotikSitesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // surface listen for MikroTik errors
    ref.listen<MikroTikState>(mikrotikProvider, (_, next) {
      if (next.status == MikroTikConnectionStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(mikrotikProvider.notifier).clearError();
      }
      if (next.isConnected && mounted) {
        context.go('/mikrotik/dashboard');
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('MikroTik Sites'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_mikrotikSitesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.cable_rounded),
            tooltip: 'Manual Connect',
            onPressed: () => context.push('/mikrotik/connect'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search sites…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) =>
                  setState(() => _search = v.trim().toLowerCase()),
            ),
          ),

          // ── body ───────────────────────────────────────────────────────
          Expanded(
            child: sitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(_mikrotikSitesProvider),
              ),
              data: (sites) {
                final filtered = _search.isEmpty
                    ? sites
                    : sites.where((s) {
                        return s.name.toLowerCase().contains(_search) ||
                            (s.location ?? '').toLowerCase().contains(_search);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.domain_disabled_rounded,
                            size: 64,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          _search.isEmpty
                              ? 'No sites found'
                              : 'No sites match "$_search"',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_mikrotikSitesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _SiteCard(site: filtered[i]),
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
// Site Card
// ─────────────────────────────────────────────────────────────────────────────

class _SiteCard extends ConsumerStatefulWidget {
  const _SiteCard({required this.site});
  final Site site;

  @override
  ConsumerState<_SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends ConsumerState<_SiteCard> {
  bool _connecting = false;

  bool get _isConfigured =>
      (widget.site.routerIp ?? '').isNotEmpty &&
      (widget.site.routerUsername ?? '').isNotEmpty;

  Future<void> _connect(BuildContext context) async {
    if (!_isConfigured) {
      await _showEditSheet(context);
      return;
    }
    setState(() => _connecting = true);
    try {
      final conn = MikroTikConnection(
        host: widget.site.routerIp!,
        port: 8728,
        username: widget.site.routerUsername!,
        password: widget.site.routerPassword ?? '',
      );
      await ref.read(mikrotikProvider.notifier).connect(conn);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _showEditSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CredentialsSheet(site: widget.site),
    );
    // Invalidate sites so card refreshes with new credentials
    ref.invalidate(_mikrotikSitesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header row ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isConfigured
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.router_rounded,
                    color: _isConfigured
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.site.name,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if ((widget.site.location ?? '').isNotEmpty)
                        Text(widget.site.location!,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                // configured badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isConfigured
                        ? Colors.green.withValues(alpha: 0.12)
                        : colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isConfigured ? 'Configured' : 'Not Set',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isConfigured
                          ? Colors.green.shade700
                          : colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── credentials info ─────────────────────────────────────────
            if (_isConfigured) ...[
              _InfoRow(
                icon: Icons.lan_rounded,
                label: 'IP / Host',
                value: widget.site.routerIp!,
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Username',
                value: widget.site.routerUsername!,
              ),
              _PasswordRow(
                hasPassword: (widget.site.routerPassword ?? '').isNotEmpty,
              ),
              const SizedBox(height: 10),
            ] else ...[
              Text(
                'No MikroTik credentials saved for this site.',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
            ],

            // ── action buttons ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditSheet(context),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(
                        _isConfigured ? 'Edit Credentials' : 'Add Credentials'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _connecting ? null : () => _connect(context),
                    icon: _connecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.power_rounded, size: 16),
                    label: Text(_connecting ? 'Connecting…' : 'Connect'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Credentials bottom-sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CredentialsSheet extends ConsumerStatefulWidget {
  const _CredentialsSheet({required this.site});
  final Site site;

  @override
  ConsumerState<_CredentialsSheet> createState() => _CredentialsSheetState();
}

class _CredentialsSheetState extends ConsumerState<_CredentialsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _obscurePass = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl =
        TextEditingController(text: widget.site.routerIp ?? '192.168.88.1');
    _portCtrl = TextEditingController(text: '8728');
    _userCtrl =
        TextEditingController(text: widget.site.routerUsername ?? 'admin');
    _passCtrl = TextEditingController(text: widget.site.routerPassword ?? '');
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(supabaseDataServiceProvider).updateSite(widget.site.id, {
        'router_ip': _ipCtrl.text.trim(),
        'router_username': _userCtrl.text.trim(),
        'router_password': _passCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MikroTik credentials saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'MikroTik Credentials',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.site.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),

            // ── IP ───────────────────────────────────────────────────────
            TextFormField(
              controller: _ipCtrl,
              decoration: _inputDeco(
                colorScheme,
                label: 'Router IP / Host',
                icon: Icons.lan_rounded,
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'IP / host required' : null,
            ),
            const SizedBox(height: 14),

            // ── Port ─────────────────────────────────────────────────────
            TextFormField(
              controller: _portCtrl,
              decoration: _inputDeco(
                colorScheme,
                label: 'API Port',
                icon: Icons.settings_ethernet_rounded,
                hint: '8728',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Port required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1 || n > 65535) return 'Invalid port';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ── Username ─────────────────────────────────────────────────
            TextFormField(
              controller: _userCtrl,
              decoration: _inputDeco(
                colorScheme,
                label: 'Username',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Username required' : null,
            ),
            const SizedBox(height: 14),

            // ── Password ─────────────────────────────────────────────────
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: _inputDeco(
                colorScheme,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : 'Save Credentials'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    String? hint,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _PasswordRow extends StatelessWidget {
  const _PasswordRow({required this.hasPassword});
  final bool hasPassword;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Password: ',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
          Text(
            hasPassword ? '••••••••' : 'Not set',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasPassword ? null : cs.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 52, color: cs.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

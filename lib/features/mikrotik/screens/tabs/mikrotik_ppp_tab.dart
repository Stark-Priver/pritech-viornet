import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mikrotik_models.dart';
import '../../providers/mikrotik_provider.dart';

class MikroTikPppTab extends ConsumerStatefulWidget {
  const MikroTikPppTab({super.key});

  @override
  ConsumerState<MikroTikPppTab> createState() => _MikroTikPppTabState();
}

class _MikroTikPppTabState extends ConsumerState<MikroTikPppTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTab;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mikrotikProvider.notifier).loadPPP();
    });
  }

  @override
  void dispose() {
    _subTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mkState = ref.watch(mikrotikProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final filteredSecrets = mkState.pppSecrets
        .where((s) =>
            _searchQuery.isEmpty ||
            s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.comment.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        // Sub-tabs
        TabBar(
          controller: _subTab,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key, size: 16),
                  const SizedBox(width: 6),
                  Text('Secrets (${mkState.pppSecrets.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 16),
                  const SizedBox(width: 6),
                  Text('Active (${mkState.pppActive.length})'),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(mikrotikProvider.notifier).loadPPP(),
            child: TabBarView(
              controller: _subTab,
              children: [
                _buildSecretsList(
                    context, colorScheme, mkState, filteredSecrets),
                _buildActiveList(context, colorScheme, mkState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecretsList(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikState mkState,
    List<MikroTikPPPSecret> secrets,
  ) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search secrets…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: mkState.isLoading && mkState.pppSecrets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : secrets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.vpn_key_off,
                                size: 60, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(_searchQuery.isNotEmpty
                                ? 'No results for "$_searchQuery"'
                                : 'No PPP secrets'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: secrets.length,
                        itemBuilder: (context, i) =>
                            _buildSecretTile(context, colorScheme, secrets[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Secret'),
        onPressed: () => _showAddSecretDialog(context),
      ),
    );
  }

  Widget _buildSecretTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikPPPSecret secret,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: secret.disabled
          ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: secret.disabled
              ? Colors.grey.shade200
              : colorScheme.secondaryContainer,
          child: Icon(
            Icons.vpn_key_outlined,
            color: secret.disabled
                ? Colors.grey
                : colorScheme.onSecondaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          secret.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: secret.disabled ? TextDecoration.lineThrough : null,
            color: secret.disabled ? colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile: ${secret.profile}  •  Service: ${secret.service}',
              style: const TextStyle(fontSize: 12),
            ),
            if (secret.comment.isNotEmpty)
              Text(
                secret.comment,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete secret',
          onPressed: () async {
            final ok = await _confirmDelete(
                context, 'Delete PPP secret "${secret.name}"?');
            if (ok) {
              try {
                await ref
                    .read(mikrotikProvider.notifier)
                    .removePPPSecret(secret.id);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildActiveList(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikState mkState,
  ) {
    if (mkState.isLoading && mkState.pppActive.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (mkState.pppActive.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 60, color: colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No active PPP sessions'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mkState.pppActive.length,
      itemBuilder: (context, i) =>
          _buildActiveTile(context, colorScheme, mkState.pppActive[i]),
    );
  }

  Widget _buildActiveTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikPPPActive active,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.15),
          child: const Icon(Icons.link, color: Colors.green, size: 20),
        ),
        title: Text(
          active.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IP: ${active.address}  •  Service: ${active.service}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Uptime: ${active.uptime}  •  Caller: ${active.callerID}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.link_off, color: Colors.orange),
          tooltip: 'Disconnect session',
          onPressed: () async {
            final ok = await _confirmDelete(
                context, 'Disconnect PPP session for "${active.name}"?');
            if (ok) {
              ref
                  .read(mikrotikProvider.notifier)
                  .disconnectPPPActive(active.id);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showAddSecretDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final profileCtrl = TextEditingController(text: 'default');
    final serviceCtrl = TextEditingController(text: 'pppoe');
    final commentCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add PPP Secret'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: profileCtrl,
                decoration: const InputDecoration(
                  labelText: 'Profile',
                  prefixIcon: Icon(Icons.settings),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serviceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Service (pppoe/pptp/l2tp)',
                  prefixIcon: Icon(Icons.vpn_lock),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (submitted == true && nameCtrl.text.trim().isNotEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      final errorColor = Theme.of(context).colorScheme.error;
      try {
        await ref.read(mikrotikProvider.notifier).addPPPSecret(
              name: nameCtrl.text.trim(),
              password: passCtrl.text,
              profile: profileCtrl.text.trim().isNotEmpty
                  ? profileCtrl.text.trim()
                  : 'default',
              service: serviceCtrl.text.trim().isNotEmpty
                  ? serviceCtrl.text.trim()
                  : 'pppoe',
              comment: commentCtrl.text.trim(),
            );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('PPP secret added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

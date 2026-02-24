import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mikrotik_models.dart';
import '../../providers/mikrotik_provider.dart';

class MikroTikHotspotTab extends ConsumerStatefulWidget {
  const MikroTikHotspotTab({super.key});

  @override
  ConsumerState<MikroTikHotspotTab> createState() => _MikroTikHotspotTabState();
}

class _MikroTikHotspotTabState extends ConsumerState<MikroTikHotspotTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTab;

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mikrotikProvider.notifier).loadHotspot();
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
                  const Icon(Icons.people, size: 16),
                  const SizedBox(width: 6),
                  Text('Users (${mkState.hotspotUsers.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_tethering, size: 16),
                  const SizedBox(width: 6),
                  Text('Active (${mkState.hotspotActive.length})'),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(mikrotikProvider.notifier).loadHotspot(),
            child: TabBarView(
              controller: _subTab,
              children: [
                _buildUsersList(context, colorScheme, mkState),
                _buildActiveList(context, colorScheme, mkState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikState mkState,
  ) {
    return Scaffold(
      body: mkState.isLoading && mkState.hotspotUsers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : mkState.hotspotUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 60, color: colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text('No hotspot users'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: mkState.hotspotUsers.length,
                  itemBuilder: (context, i) => _buildUserTile(
                      context, colorScheme, mkState.hotspotUsers[i]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        onPressed: () => _showAddUserDialog(context),
      ),
    );
  }

  Widget _buildUserTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikHotspotUser user,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: user.disabled
          ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.disabled
              ? Colors.grey.shade200
              : colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            color: user.disabled ? Colors.grey : colorScheme.primary,
          ),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: user.disabled ? TextDecoration.lineThrough : null,
            color: user.disabled ? colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile: ${user.profile}',
              style: const TextStyle(fontSize: 12),
            ),
            if (user.comment.isNotEmpty)
              Text(
                user.comment,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'toggle') {
              await ref
                  .read(mikrotikProvider.notifier)
                  .toggleHotspotUser(user.id, !user.disabled);
            } else if (value == 'delete') {
              final ok = await _confirmDelete(
                  context, 'Delete hotspot user "${user.name}"?');
              if (ok) {
                try {
                  await ref
                      .read(mikrotikProvider.notifier)
                      .removeHotspotUser(user.id);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                      user.disabled ? Icons.check_circle_outline : Icons.block),
                  const SizedBox(width: 8),
                  Text(user.disabled ? 'Enable' : 'Disable'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveList(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikState mkState,
  ) {
    if (mkState.isLoading && mkState.hotspotActive.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (mkState.hotspotActive.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 60, color: colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No active sessions'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mkState.hotspotActive.length,
      itemBuilder: (context, i) =>
          _buildActiveTile(context, colorScheme, mkState.hotspotActive[i]),
    );
  }

  Widget _buildActiveTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikHotspotActive active,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.15),
          child: const Icon(Icons.wifi, color: Colors.green, size: 20),
        ),
        title: Text(
          active.user,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP: ${active.address}  •  MAC: ${active.macAddress}',
                style: const TextStyle(fontSize: 11)),
            Text('Uptime: ${active.uptime}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          tooltip: 'Kick session',
          onPressed: () async {
            final ok = await _confirmDelete(
                context, 'Kick active session for "${active.user}"?');
            if (ok) {
              ref.read(mikrotikProvider.notifier).kickHotspotActive(active.id);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final profileCtrl = TextEditingController(text: 'default');
    final commentCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Hotspot User'),
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
        await ref.read(mikrotikProvider.notifier).addHotspotUser(
              name: nameCtrl.text.trim(),
              password: passCtrl.text,
              profile: profileCtrl.text.trim().isNotEmpty
                  ? profileCtrl.text.trim()
                  : 'default',
              comment: commentCtrl.text.trim(),
            );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Hotspot user added successfully'),
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

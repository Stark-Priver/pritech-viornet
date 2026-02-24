import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/mikrotik_provider.dart';
import 'tabs/mikrotik_dashboard_tab.dart';
import 'tabs/mikrotik_interfaces_tab.dart';
import 'tabs/mikrotik_hotspot_tab.dart';
import 'tabs/mikrotik_ppp_tab.dart';
import 'tabs/mikrotik_ip_tab.dart';
import 'tabs/mikrotik_profiles_tab.dart';

class MikroTikDashboardScreen extends ConsumerStatefulWidget {
  const MikroTikDashboardScreen({super.key});

  @override
  ConsumerState<MikroTikDashboardScreen> createState() =>
      _MikroTikDashboardScreenState();
}

class _MikroTikDashboardScreenState
    extends ConsumerState<MikroTikDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _tabs = const [
    Tab(icon: Icon(Icons.dashboard_outlined), text: 'System'),
    Tab(icon: Icon(Icons.cable), text: 'Interfaces'),
    Tab(icon: Icon(Icons.wifi_tethering), text: 'Hotspot'),
    Tab(icon: Icon(Icons.vpn_key_outlined), text: 'PPPoE'),
    Tab(icon: Icon(Icons.lan_outlined), text: 'IP / DHCP'),
    Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Profiles'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect'),
        content:
            const Text('Are you sure you want to disconnect from the router?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(mikrotikProvider.notifier).disconnect();
      if (mounted) context.go('/mikrotik');
    }
  }

  Future<void> _confirmReboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Reboot Router'),
        content: const Text(
          'This will restart the MikroTik router. '
          'All active connections will be dropped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade100,
              foregroundColor: Colors.orange.shade900,
            ),
            child: const Text('Reboot'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rebooting router…'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ref.read(mikrotikProvider.notifier).rebootRouter();
      if (mounted) context.go('/mikrotik');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mkState = ref.watch(mikrotikProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // If somehow we land here while disconnected, redirect
    if (!mkState.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/mikrotik');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final identity = mkState.systemInfo?.identity.isNotEmpty == true
        ? mkState.systemInfo!.identity
        : mkState.connection?.host ?? 'Router';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    mkState.connection?.host ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reboot Router',
            onPressed: _confirmReboot,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Disconnect',
            onPressed: _disconnect,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MikroTikDashboardTab(),
          MikroTikInterfacesTab(),
          MikroTikHotspotTab(),
          MikroTikPppTab(),
          MikroTikIpTab(),
          MikroTikProfilesTab(),
        ],
      ),
    );
  }
}

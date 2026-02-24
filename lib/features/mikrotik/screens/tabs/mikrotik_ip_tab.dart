import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mikrotik_models.dart';
import '../../providers/mikrotik_provider.dart';

class MikroTikIpTab extends ConsumerStatefulWidget {
  const MikroTikIpTab({super.key});

  @override
  ConsumerState<MikroTikIpTab> createState() => _MikroTikIpTabState();
}

class _MikroTikIpTabState extends ConsumerState<MikroTikIpTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTab;

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mikrotikProvider.notifier).loadIpAndDhcp();
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
        TabBar(
          controller: _subTab,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lan_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('IP Addresses (${mkState.ipAddresses.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.devices, size: 16),
                  const SizedBox(width: 6),
                  Text('DHCP Leases (${mkState.dhcpLeases.length})'),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(mikrotikProvider.notifier).loadIpAndDhcp(),
            child: TabBarView(
              controller: _subTab,
              children: [
                _buildIpList(context, colorScheme, mkState),
                _buildDhcpList(context, colorScheme, mkState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIpList(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikState mkState,
  ) {
    if (mkState.isLoading && mkState.ipAddresses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (mkState.ipAddresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lan_outlined, size: 60, color: colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No IP addresses'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(mikrotikProvider.notifier).loadIpAndDhcp(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mkState.ipAddresses.length,
      itemBuilder: (context, i) =>
          _buildIpTile(context, colorScheme, mkState.ipAddresses[i]),
    );
  }

  Widget _buildIpTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikIpAddress ip,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: ip.disabled
          ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ip.disabled
              ? Colors.grey.shade200
              : colorScheme.tertiaryContainer,
          child: Icon(
            ip.dynamic ? Icons.auto_awesome : Icons.lan,
            color: ip.disabled ? Colors.grey : colorScheme.onTertiaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          ip.address,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            decoration: ip.disabled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interface: ${ip.interface}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Network: ${ip.network}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ip.dynamic)
              _badge('Dynamic', Colors.orange)
            else
              _badge('Static', Colors.blue),
            const SizedBox(width: 6),
            if (ip.disabled) _badge('Disabled', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildDhcpList(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikState mkState,
  ) {
    if (mkState.isLoading && mkState.dhcpLeases.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (mkState.dhcpLeases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 60, color: colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No DHCP leases'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mkState.dhcpLeases.length,
      itemBuilder: (context, i) =>
          _buildDhcpTile(context, colorScheme, mkState.dhcpLeases[i]),
    );
  }

  Widget _buildDhcpTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikDhcpLease lease,
  ) {
    final isBound = lease.status == 'bound';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isBound
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          child: Icon(
            Icons.devices,
            color: isBound ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          lease.address,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MAC: ${lease.macAddress}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            if (lease.hostname.isNotEmpty)
              Text(
                'Host: ${lease.hostname}',
                style: const TextStyle(fontSize: 12),
              ),
            if (lease.expiresAfter.isNotEmpty)
              Text(
                'Expires: ${lease.expiresAfter}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _badge(
              lease.status.isNotEmpty ? lease.status : 'unknown',
              isBound ? Colors.green : Colors.grey,
            ),
            if (lease.dynamic) ...[
              const SizedBox(height: 4),
              _badge('Dynamic', Colors.orange),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color.withOpacity(0.9),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

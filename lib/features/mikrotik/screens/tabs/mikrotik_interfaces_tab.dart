import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mikrotik_models.dart';
import '../../providers/mikrotik_provider.dart';

class MikroTikInterfacesTab extends ConsumerStatefulWidget {
  const MikroTikInterfacesTab({super.key});

  @override
  ConsumerState<MikroTikInterfacesTab> createState() =>
      _MikroTikInterfacesTabState();
}

class _MikroTikInterfacesTabState extends ConsumerState<MikroTikInterfacesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mikrotikProvider.notifier).loadInterfaces();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mkState = ref.watch(mikrotikProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final interfaces = mkState.interfaces;

    return RefreshIndicator(
      onRefresh: () => ref.read(mikrotikProvider.notifier).loadInterfaces(),
      child: mkState.isLoading && interfaces.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : interfaces.isEmpty
              ? _buildEmpty(context, ref)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: interfaces.length,
                  itemBuilder: (context, i) =>
                      _buildInterfaceTile(context, colorScheme, interfaces[i]),
                ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cable,
              size: 60, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('No interfaces found'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(mikrotikProvider.notifier).loadInterfaces(),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildInterfaceTile(
    BuildContext context,
    ColorScheme colorScheme,
    MikroTikInterface iface,
  ) {
    final statusColor = iface.disabled
        ? Colors.grey
        : iface.running
            ? Colors.green
            : Colors.orange;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            _iconForType(iface.type),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          iface.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${iface.type}  •  ${iface.macAddress}',
              style: const TextStyle(fontSize: 12),
            ),
            Row(
              children: [
                _statChip('↑ ${_formatBytes(iface.txByte)}', Colors.blue),
                const SizedBox(width: 6),
                _statChip('↓ ${_formatBytes(iface.rxByte)}', Colors.green),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: !iface.disabled,
              onChanged: (_) =>
                  ref.read(mikrotikProvider.notifier).toggleInterface(iface),
              activeThumbColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'ether':
        return Icons.settings_ethernet;
      case 'wlan':
        return Icons.wifi;
      case 'bridge':
        return Icons.device_hub;
      case 'vlan':
        return Icons.layers;
      case 'pppoe-client':
      case 'pppoe':
        return Icons.vpn_lock;
      default:
        return Icons.cable;
    }
  }

  String _formatBytes(String byteStr) {
    final b = int.tryParse(byteStr) ?? 0;
    if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(1)} GB';
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }
}

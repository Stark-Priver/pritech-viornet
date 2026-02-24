import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mikrotik_models.dart';
import '../../providers/mikrotik_provider.dart';

class MikroTikDashboardTab extends ConsumerWidget {
  const MikroTikDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mkState = ref.watch(mikrotikProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final info = mkState.systemInfo;

    return RefreshIndicator(
      onRefresh: () => ref.read(mikrotikProvider.notifier).loadSystemInfo(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mkState.isLoading && info == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (info == null)
              _buildEmpty(context, ref)
            else ...[
              // Identity / board card
              _buildIdentityCard(context, colorScheme, info),
              const SizedBox(height: 12),

              // Resource gauges row
              Row(
                children: [
                  Expanded(
                    child: _buildGaugeCard(
                      context,
                      colorScheme,
                      'CPU Load',
                      '${info.cpuLoad}%',
                      double.tryParse(info.cpuLoad) ?? 0,
                      Icons.speed,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGaugeCard(
                      context,
                      colorScheme,
                      'Memory',
                      '${info.memoryUsagePercent}%',
                      double.tryParse(info.memoryUsagePercent) ?? 0,
                      Icons.memory,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGaugeCard(
                      context,
                      colorScheme,
                      'Disk',
                      '${info.hddUsagePercent}%',
                      double.tryParse(info.hddUsagePercent) ?? 0,
                      Icons.storage,
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details grid
              _buildInfoGrid(context, colorScheme, info),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.info_outline,
            size: 60,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text('No system info loaded'),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(mikrotikProvider.notifier).loadSystemInfo(),
            child: const Text('Load Info'),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(
      BuildContext context, ColorScheme colorScheme, MikroTikSystemInfo info) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.router, color: colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.identity.isNotEmpty ? info.identity : 'MikroTik',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info.board}  •  RouterOS ${info.version}',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  if (info.uptime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color:
                              colorScheme.onPrimaryContainer.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Uptime: ${info.uptime}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeCard(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
    String value,
    double percent,
    IconData icon,
    Color color,
  ) {
    final ratio = (percent / 100).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(
      BuildContext context, ColorScheme colorScheme, MikroTikSystemInfo info) {
    final items = <_InfoItem>[
      _InfoItem('Architecture', info.architecture, Icons.engineering),
      _InfoItem('CPU', info.cpu, Icons.memory),
      _InfoItem(
        'Total Memory',
        MikroTikSystemInfo.formatBytes(info.totalMemory),
        Icons.sd_card,
      ),
      _InfoItem(
        'Free Memory',
        MikroTikSystemInfo.formatBytes(info.freeMemory),
        Icons.sd_card_alert_outlined,
      ),
      _InfoItem(
        'Total HDD',
        MikroTikSystemInfo.formatBytes(info.totalHdd),
        Icons.storage,
      ),
      _InfoItem(
        'Free HDD',
        MikroTikSystemInfo.formatBytes(info.freeHdd),
        Icons.folder_outlined,
      ),
    ];

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hardware Details',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(item.icon,
                        size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      item.value.isNotEmpty ? item.value : '—',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  const _InfoItem(this.label, this.value, this.icon);
}

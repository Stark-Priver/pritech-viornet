import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import 'site_isp_subscription_screen.dart';

class IspSubscriptionOverviewScreen extends ConsumerWidget {
  const IspSubscriptionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ISP Subscriptions Overview')),
      body: FutureBuilder<List<Site>>(
        future: db.select(db.sites).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final sites = snapshot.data ?? [];
          if (sites.isEmpty) {
            return const Center(child: Text('No sites found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final site = sites[index];
              return ListTile(
                title: Text(site.name),
                subtitle: site.location != null ? Text(site.location!) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SiteIspSubscriptionScreen(site: site),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

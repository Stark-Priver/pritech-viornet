import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sites/screens/site_isp_subscription_screen.dart';
import '../database/database.dart';
import '../providers/providers.dart';

class SiteIspSubscriptionScreenLoader extends ConsumerWidget {
  final int siteId;
  const SiteIspSubscriptionScreenLoader({super.key, required this.siteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Site?>(
      future: (db.select(db.sites)..where((tbl) => tbl.id.equals(siteId)))
          .getSingleOrNull(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final site = snapshot.data;
        if (site == null) {
          return const Scaffold(body: Center(child: Text('Site not found.')));
        }
        return SiteIspSubscriptionScreen(site: site);
      },
    );
  }
}

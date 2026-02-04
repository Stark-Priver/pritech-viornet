import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class SiteRepository {
  final AppDatabase _database;

  SiteRepository(this._database);

  // Create site
  Future<int> createSite(SitesCompanion site) async {
    return await _database.into(_database.sites).insert(site);
  }

  // Get all sites
  Future<List<Site>> getAllSites() async {
    return await _database.select(_database.sites).get();
  }

  // Get active sites
  Future<List<Site>> getActiveSites() async {
    return await (_database.select(
      _database.sites,
    )..where((tbl) => tbl.isActive.equals(true)))
        .get();
  }

  // Get site by ID
  Future<Site?> getSiteById(int id) async {
    return await (_database.select(
      _database.sites,
    )..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Search sites
  Future<List<Site>> searchSites(String query) async {
    return await (_database.select(_database.sites)
          ..where(
            (tbl) => tbl.name.contains(query) | tbl.location.contains(query),
          ))
        .get();
  }

  // Update site
  Future<bool> updateSite(int id, SitesCompanion site) async {
    return await (_database.update(
          _database.sites,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          site.copyWith(
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Delete site
  Future<int> deleteSite(int id) async {
    return await (_database.delete(
      _database.sites,
    )..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get site count
  Future<int> getSiteCount() async {
    final sites = await getAllSites();
    return sites.length;
  }
}

import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class AssetRepository {
  final AppDatabase _database;

  AssetRepository(this._database);

  // Create asset
  Future<int> createAsset(AssetsCompanion asset) async {
    return await _database.into(_database.assets).insert(asset);
  }

  // Get all assets
  Future<List<Asset>> getAllAssets() async {
    return await _database.select(_database.assets).get();
  }

  // Get active assets
  Future<List<Asset>> getActiveAssets() async {
    return await (_database.select(
      _database.assets,
    )..where((tbl) => tbl.isActive.equals(true)))
        .get();
  }

  // Get asset by ID
  Future<Asset?> getAssetById(int id) async {
    return await (_database.select(
      _database.assets,
    )..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get assets by site
  Future<List<Asset>> getAssetsBySite(int siteId) async {
    return await (_database.select(
      _database.assets,
    )..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  // Get assets by type
  Future<List<Asset>> getAssetsByType(String type) async {
    return await (_database.select(
      _database.assets,
    )..where((tbl) => tbl.type.equals(type)))
        .get();
  }

  // Search assets
  Future<List<Asset>> searchAssets(String query) async {
    return await (_database.select(_database.assets)
          ..where(
            (tbl) =>
                tbl.name.contains(query) |
                tbl.serialNumber.contains(query) |
                tbl.model.contains(query),
          ))
        .get();
  }

  // Update asset
  Future<bool> updateAsset(int id, AssetsCompanion asset) async {
    return await (_database.update(
          _database.assets,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          asset.copyWith(
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Delete asset
  Future<int> deleteAsset(int id) async {
    return await (_database.delete(
      _database.assets,
    )..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get asset count
  Future<int> getAssetCount() async {
    final assets = await getAllAssets();
    return assets.length;
  }

  // Get assets by condition
  Future<List<Asset>> getAssetsByCondition(String condition) async {
    return await (_database.select(
      _database.assets,
    )..where((tbl) => tbl.condition.equals(condition)))
        .get();
  }
}

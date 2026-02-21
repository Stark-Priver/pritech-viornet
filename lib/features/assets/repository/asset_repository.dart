import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';

class AssetRepository {
  final SupabaseDataService _service;

  AssetRepository(this._service);

  Future<Asset> createAsset(Map<String, dynamic> fields) =>
      _service.createAsset(fields);

  Future<List<Asset>> getAllAssets() => _service.getAllAssets();

  Future<List<Asset>> getActiveAssets() => _service.getActiveAssets();

  Future<Asset?> getAssetById(int id) => _service.getAssetById(id);

  Future<List<Asset>> getAssetsBySite(int siteId) =>
      _service.getAssetsBySite(siteId);

  Future<List<Asset>> getAssetsByType(String type) =>
      _service.getAssetsByType(type);

  Future<List<Asset>> searchAssets(String query) =>
      _service.searchAssets(query);

  Future<bool> updateAsset(int id, Map<String, dynamic> fields) =>
      _service.updateAsset(id, fields);

  Future<void> deleteAsset(int id) => _service.deleteAsset(id);

  Future<int> getAssetCount() => _service.getAssetCount();

  Future<List<Asset>> getAssetsByCondition(String condition) =>
      _service.getAssetsByCondition(condition);
}

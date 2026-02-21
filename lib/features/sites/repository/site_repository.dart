import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';

class SiteRepository {
  final SupabaseDataService _service;

  SiteRepository(this._service);

  Future<List<Site>> getAllSites() => _service.getAllSites();

  Future<List<Site>> getActiveSites() => _service.getActiveSites();

  Future<Site?> getSiteById(int id) => _service.getSiteById(id);

  Future<List<Site>> searchSites(String query) => _service.searchSites(query);

  Future<Site> createSite(Map<String, dynamic> fields) =>
      _service.createSite(fields);

  Future<bool> updateSite(int id, Map<String, dynamic> fields) =>
      _service.updateSite(id, fields);

  Future<void> deleteSite(int id) => _service.deleteSite(id);

  Future<int> getSiteCount() async {
    final sites = await getAllSites();
    return sites.length;
  }
}

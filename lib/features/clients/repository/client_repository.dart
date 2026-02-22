import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';

class ClientRepository {
  final SupabaseDataService _service;

  ClientRepository(this._service);

  Future<Client> createClient(Map<String, dynamic> fields) =>
      _service.createClient(fields);

  Future<List<Client>> getAllClients() => _service.getAllClients();

  Future<List<Client>> getClientsByUser(int userId) =>
      _service.getClientsByUser(userId);

  Future<Client?> getClientById(int id) => _service.getClientById(id);

  Future<List<Client>> getClientsBySite(int siteId) =>
      _service.getClientsBySite(siteId);

  Future<List<Client>> searchClients(String query) =>
      _service.searchClients(query);

  Future<List<Client>> getActiveClients() => _service.getActiveClients();

  Future<List<Client>> getExpiringClients(int days) =>
      _service.getExpiringClients(days);

  Future<List<Client>> getExpiredClients() => _service.getExpiredClients();

  Future<bool> updateClient(int id, Map<String, dynamic> fields) =>
      _service.updateClient(id, fields);

  Future<void> deleteClient(int id) => _service.deleteClient(id);

  Future<int> getClientCount() => _service.getClientCount();

  Future<int> getActiveClientCount() => _service.getActiveClientCount();

  Future<List<Client>> getClientsPaginated(
          {required int page, required int pageSize}) =>
      _service.getClientsPaginated(page: page, pageSize: pageSize);
}

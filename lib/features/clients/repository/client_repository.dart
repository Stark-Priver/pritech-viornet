import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class ClientRepository {
  final AppDatabase _database;

  ClientRepository(this._database);

  // Create client
  Future<int> createClient(ClientsCompanion client) async {
    return await _database.into(_database.clients).insert(client);
  }

  // Get all clients
  Future<List<Client>> getAllClients() async {
    return await _database.select(_database.clients).get();
  }

  // Get client by ID
  Future<Client?> getClientById(int id) async {
    return await (_database.select(
      _database.clients,
    )..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get clients by site
  Future<List<Client>> getClientsBySite(int siteId) async {
    return await (_database.select(
      _database.clients,
    )..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  // Search clients
  Future<List<Client>> searchClients(String query) async {
    return await (_database.select(_database.clients)
          ..where(
            (tbl) =>
                tbl.name.contains(query) |
                tbl.phone.contains(query) |
                tbl.email.contains(query),
          ))
        .get();
  }

  // Get active clients
  Future<List<Client>> getActiveClients() async {
    return await (_database.select(
      _database.clients,
    )..where((tbl) => tbl.isActive.equals(true)))
        .get();
  }

  // Get expiring clients (within days)
  Future<List<Client>> getExpiringClients(int days) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    return await (_database.select(_database.clients)
          ..where(
            (tbl) =>
                tbl.expiryDate.isSmallerOrEqualValue(futureDate) &
                tbl.expiryDate.isBiggerOrEqualValue(now) &
                tbl.isActive.equals(true),
          ))
        .get();
  }

  // Get expired clients
  Future<List<Client>> getExpiredClients() async {
    final now = DateTime.now();

    return await (_database.select(
      _database.clients,
    )..where((tbl) => tbl.expiryDate.isSmallerThanValue(now)))
        .get();
  }

  // Update client
  Future<bool> updateClient(int id, ClientsCompanion client) async {
    return await (_database.update(
          _database.clients,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          client.copyWith(
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Delete client
  Future<int> deleteClient(int id) async {
    return await (_database.delete(
      _database.clients,
    )..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get client count
  Future<int> getClientCount() async {
    final count = await _database.select(_database.clients).get();
    return count.length;
  }

  // Get active client count
  Future<int> getActiveClientCount() async {
    final count = await (_database.select(
      _database.clients,
    )..where((tbl) => tbl.isActive.equals(true)))
        .get();
    return count.length;
  }

  // Get clients with pagination
  Future<List<Client>> getClientsPaginated({
    required int page,
    required int pageSize,
  }) async {
    final offset = (page - 1) * pageSize;
    return await (_database.select(_database.clients)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(pageSize, offset: offset))
        .get();
  }
}

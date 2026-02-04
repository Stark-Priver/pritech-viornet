import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class MaintenanceRepository {
  final AppDatabase _database;

  MaintenanceRepository(this._database);

  // Create maintenance record
  Future<int> createMaintenance(MaintenanceCompanion maintenance) async {
    return await _database.into(_database.maintenance).insert(maintenance);
  }

  // Get all maintenance records
  Future<List<MaintenanceData>> getAllMaintenance() async {
    return await _database.select(_database.maintenance).get();
  }

  // Get maintenance by ID
  Future<MaintenanceData?> getMaintenanceById(int id) async {
    return await (_database.select(
      _database.maintenance,
    )..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get maintenance by status
  Future<List<MaintenanceData>> getMaintenanceByStatus(String status) async {
    return await (_database.select(
      _database.maintenance,
    )..where((tbl) => tbl.status.equals(status)))
        .get();
  }

  // Get pending maintenance
  Future<List<MaintenanceData>> getPendingMaintenance() async {
    return await getMaintenanceByStatus('PENDING');
  }

  // Get maintenance by site
  Future<List<MaintenanceData>> getMaintenanceBySite(int siteId) async {
    return await (_database.select(
      _database.maintenance,
    )..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  // Get maintenance by asset
  Future<List<MaintenanceData>> getMaintenanceByAsset(int assetId) async {
    return await (_database.select(
      _database.maintenance,
    )..where((tbl) => tbl.assetId.equals(assetId)))
        .get();
  }

  // Get maintenance assigned to technician
  Future<List<MaintenanceData>> getMaintenanceByTechnician(
    int technicianId,
  ) async {
    return await (_database.select(
      _database.maintenance,
    )..where((tbl) => tbl.assignedTo.equals(technicianId)))
        .get();
  }

  // Update maintenance
  Future<bool> updateMaintenance(
    int id,
    MaintenanceCompanion maintenance,
  ) async {
    return await (_database.update(
          _database.maintenance,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          maintenance.copyWith(
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Complete maintenance
  Future<bool> completeMaintenance(
    int id,
    String resolution,
    double? cost,
  ) async {
    return await (_database.update(
          _database.maintenance,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          MaintenanceCompanion(
            status: const Value('COMPLETED'),
            completedDate: Value(DateTime.now()),
            resolution: Value(resolution),
            cost: cost != null ? Value(cost) : const Value.absent(),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Delete maintenance
  Future<int> deleteMaintenance(int id) async {
    return await (_database.delete(
      _database.maintenance,
    )..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get maintenance count by status
  Future<Map<String, int>> getMaintenanceCounts() async {
    final all = await getAllMaintenance();
    return {
      'total': all.length,
      'pending': all.where((m) => m.status == 'PENDING').length,
      'in_progress': all.where((m) => m.status == 'IN_PROGRESS').length,
      'completed': all.where((m) => m.status == 'COMPLETED').length,
    };
  }
}

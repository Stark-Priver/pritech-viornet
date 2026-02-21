import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';

class MaintenanceRepository {
  final SupabaseDataService _service;

  MaintenanceRepository(this._service);

  Future<MaintenanceRecord> createMaintenance(Map<String, dynamic> fields) =>
      _service.createMaintenance(fields);

  Future<List<MaintenanceRecord>> getAllMaintenance() =>
      _service.getAllMaintenance();

  Future<MaintenanceRecord?> getMaintenanceById(int id) =>
      _service.getMaintenanceById(id);

  Future<List<MaintenanceRecord>> getMaintenanceByStatus(String status) =>
      _service.getMaintenanceByStatus(status);

  Future<List<MaintenanceRecord>> getPendingMaintenance() =>
      _service.getMaintenanceByStatus('PENDING');

  Future<List<MaintenanceRecord>> getMaintenanceBySite(int siteId) =>
      _service.getMaintenanceBySite(siteId);

  Future<List<MaintenanceRecord>> getMaintenanceByAsset(int assetId) =>
      _service.getMaintenanceByAsset(assetId);

  Future<List<MaintenanceRecord>> getMaintenanceByTechnician(
          int technicianId) =>
      _service.getMaintenanceByTechnician(technicianId);

  Future<bool> updateMaintenance(int id, Map<String, dynamic> fields) =>
      _service.updateMaintenance(id, fields);

  Future<bool> completeMaintenance(int id, String resolution, double? cost) =>
      _service.completeMaintenance(id, resolution, cost);

  Future<void> deleteMaintenance(int id) => _service.deleteMaintenance(id);

  Future<Map<String, int>> getMaintenanceCounts() =>
      _service.getMaintenanceCounts();
}

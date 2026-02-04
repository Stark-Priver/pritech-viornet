import 'dart:async';
import 'package:logger/logger.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'secure_storage_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final AppDatabase _database = AppDatabase();
  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SecureStorageService _storage = SecureStorageService();
  final Logger _logger = Logger();

  Timer? _syncTimer;
  bool _isSyncing = false;

  // Start automatic sync
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) => syncAll());
  }

  // Stop automatic sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Sync all data
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress');
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    final isConnected = await _connectivity.isConnected();
    if (!isConnected) {
      _logger.w('No internet connection');
      return SyncResult(success: false, message: 'No internet connection');
    }

    _isSyncing = true;
    _logger.i('Starting sync...');

    try {
      // Push local changes to server
      await _pushLocalChanges();

      // Pull server updates
      await _pullServerUpdates();

      // Update last sync time
      await _storage.saveLastSyncTime(DateTime.now());

      _logger.i('Sync completed successfully');
      return SyncResult(success: true, message: 'Sync completed successfully');
    } catch (e) {
      _logger.e('Sync failed', error: e);
      return SyncResult(success: false, message: 'Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Push local unsynced data to server
  Future<void> _pushLocalChanges() async {
    _logger.i('Pushing local changes...');

    // Push Users
    final unsyncedUsers = await (_database.select(
      _database.users,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final user in unsyncedUsers) {
      await _syncUser(user);
    }

    // Push Sites
    final unsyncedSites = await (_database.select(
      _database.sites,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final site in unsyncedSites) {
      await _syncSite(site);
    }

    // Push Clients
    final unsyncedClients = await (_database.select(
      _database.clients,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final client in unsyncedClients) {
      await _syncClient(client);
    }

    // Push Vouchers
    final unsyncedVouchers = await (_database.select(
      _database.vouchers,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final voucher in unsyncedVouchers) {
      await _syncVoucher(voucher);
    }

    // Push Sales
    final unsyncedSales = await (_database.select(
      _database.sales,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final sale in unsyncedSales) {
      await _syncSale(sale);
    }

    // Push Expenses
    final unsyncedExpenses = await (_database.select(
      _database.expenses,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final expense in unsyncedExpenses) {
      await _syncExpense(expense);
    }

    // Push Assets
    final unsyncedAssets = await (_database.select(
      _database.assets,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final asset in unsyncedAssets) {
      await _syncAsset(asset);
    }

    // Push Maintenance
    final unsyncedMaintenance = await (_database.select(
      _database.maintenance,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final maintenance in unsyncedMaintenance) {
      await _syncMaintenance(maintenance);
    }

    // Push SMS Logs
    final unsyncedSmsLogs = await (_database.select(
      _database.smsLogs,
    )..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    for (final smsLog in unsyncedSmsLogs) {
      await _syncSmsLog(smsLog);
    }
  }

  // Pull server updates
  Future<void> _pullServerUpdates() async {
    _logger.i('Pulling server updates...');

    try {
      final lastSyncTime = await _storage.getLastSyncTime();
      final queryParams = lastSyncTime != null
          ? {'since': lastSyncTime.toIso8601String()}
          : null;

      // Pull all data from server
      final response = await _apiService.get(
        '/sync/pull',
        queryParameters: queryParams,
      );
      final data = response.data;

      // Update local database with server data
      if (data['users'] != null) {
        // Update users...
      }
      if (data['sites'] != null) {
        // Update sites...
      }
      // ... etc for other entities
    } catch (e) {
      _logger.e('Error pulling server updates', error: e);
      rethrow;
    }
  }

  // Individual sync methods
  Future<void> _syncUser(User user) async {
    try {
      if (user.serverId == null) {
        // Create on server
        final response = await _apiService.post(
          '/users',
          data: _userToJson(user),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.users,
        )..where((tbl) => tbl.id.equals(user.id)))
            .write(
          UsersCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        // Update on server
        await _apiService.put(
          '/users/${user.serverId}',
          data: _userToJson(user),
        );
        await (_database.update(
          _database.users,
        )..where((tbl) => tbl.id.equals(user.id)))
            .write(
          UsersCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing user', error: e);
    }
  }

  Future<void> _syncSite(Site site) async {
    try {
      if (site.serverId == null) {
        final response = await _apiService.post(
          '/sites',
          data: _siteToJson(site),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.sites,
        )..where((tbl) => tbl.id.equals(site.id)))
            .write(
          SitesCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/sites/${site.serverId}',
          data: _siteToJson(site),
        );
        await (_database.update(
          _database.sites,
        )..where((tbl) => tbl.id.equals(site.id)))
            .write(
          SitesCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing site', error: e);
    }
  }

  Future<void> _syncClient(Client client) async {
    try {
      if (client.serverId == null) {
        final response = await _apiService.post(
          '/clients',
          data: _clientToJson(client),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.clients,
        )..where((tbl) => tbl.id.equals(client.id)))
            .write(
          ClientsCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/clients/${client.serverId}',
          data: _clientToJson(client),
        );
        await (_database.update(
          _database.clients,
        )..where((tbl) => tbl.id.equals(client.id)))
            .write(
          ClientsCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing client', error: e);
    }
  }

  Future<void> _syncVoucher(Voucher voucher) async {
    try {
      if (voucher.serverId == null) {
        final response = await _apiService.post(
          '/vouchers',
          data: _voucherToJson(voucher),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.vouchers,
        )..where((tbl) => tbl.id.equals(voucher.id)))
            .write(
          VouchersCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/vouchers/${voucher.serverId}',
          data: _voucherToJson(voucher),
        );
        await (_database.update(
          _database.vouchers,
        )..where((tbl) => tbl.id.equals(voucher.id)))
            .write(
          VouchersCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing voucher', error: e);
    }
  }

  Future<void> _syncSale(Sale sale) async {
    try {
      if (sale.serverId == null) {
        final response = await _apiService.post(
          '/sales',
          data: _saleToJson(sale),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.sales,
        )..where((tbl) => tbl.id.equals(sale.id)))
            .write(
          SalesCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/sales/${sale.serverId}',
          data: _saleToJson(sale),
        );
        await (_database.update(
          _database.sales,
        )..where((tbl) => tbl.id.equals(sale.id)))
            .write(
          SalesCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing sale', error: e);
    }
  }

  Future<void> _syncExpense(Expense expense) async {
    try {
      if (expense.serverId == null) {
        final response = await _apiService.post(
          '/expenses',
          data: _expenseToJson(expense),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.expenses,
        )..where((tbl) => tbl.id.equals(expense.id)))
            .write(
          ExpensesCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/expenses/${expense.serverId}',
          data: _expenseToJson(expense),
        );
        await (_database.update(
          _database.expenses,
        )..where((tbl) => tbl.id.equals(expense.id)))
            .write(
          ExpensesCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing expense', error: e);
    }
  }

  Future<void> _syncAsset(Asset asset) async {
    try {
      if (asset.serverId == null) {
        final response = await _apiService.post(
          '/assets',
          data: _assetToJson(asset),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.assets,
        )..where((tbl) => tbl.id.equals(asset.id)))
            .write(
          AssetsCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/assets/${asset.serverId}',
          data: _assetToJson(asset),
        );
        await (_database.update(
          _database.assets,
        )..where((tbl) => tbl.id.equals(asset.id)))
            .write(
          AssetsCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing asset', error: e);
    }
  }

  Future<void> _syncMaintenance(MaintenanceData maintenance) async {
    try {
      if (maintenance.serverId == null) {
        final response = await _apiService.post(
          '/maintenance',
          data: _maintenanceToJson(maintenance),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.maintenance,
        )..where((tbl) => tbl.id.equals(maintenance.id)))
            .write(
          MaintenanceCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/maintenance/${maintenance.serverId}',
          data: _maintenanceToJson(maintenance),
        );
        await (_database.update(
          _database.maintenance,
        )..where((tbl) => tbl.id.equals(maintenance.id)))
            .write(
          MaintenanceCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing maintenance', error: e);
    }
  }

  Future<void> _syncSmsLog(SmsLog smsLog) async {
    try {
      if (smsLog.serverId == null) {
        final response = await _apiService.post(
          '/sms-logs',
          data: _smsLogToJson(smsLog),
        );
        final serverId = response.data['id'].toString();
        await (_database.update(
          _database.smsLogs,
        )..where((tbl) => tbl.id.equals(smsLog.id)))
            .write(
          SmsLogsCompanion(
            serverId: Value(serverId),
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _apiService.put(
          '/sms-logs/${smsLog.serverId}',
          data: _smsLogToJson(smsLog),
        );
        await (_database.update(
          _database.smsLogs,
        )..where((tbl) => tbl.id.equals(smsLog.id)))
            .write(
          SmsLogsCompanion(
            isSynced: const Value(true),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error syncing SMS log', error: e);
    }
  }

  // Helper methods to convert entities to JSON
  Map<String, dynamic> _userToJson(User user) => {
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'is_active': user.isActive,
      };

  Map<String, dynamic> _siteToJson(Site site) => {
        'name': site.name,
        'location': site.location,
        'gps_coordinates': site.gpsCoordinates,
        'router_ip': site.routerIp,
        'contact_person': site.contactPerson,
        'contact_phone': site.contactPhone,
        'is_active': site.isActive,
      };

  Map<String, dynamic> _clientToJson(Client client) => {
        'name': client.name,
        'phone': client.phone,
        'email': client.email,
        'mac_address': client.macAddress,
        'site_id': client.siteId,
        'address': client.address,
        'is_active': client.isActive,
      };

  Map<String, dynamic> _voucherToJson(Voucher voucher) => {
        'code': voucher.code,
        'duration': voucher.duration,
        'price': voucher.price,
        'status': voucher.status,
        'site_id': voucher.siteId,
      };

  Map<String, dynamic> _saleToJson(Sale sale) => {
        'receipt_number': sale.receiptNumber,
        'voucher_id': sale.voucherId,
        'client_id': sale.clientId,
        'agent_id': sale.agentId,
        'amount': sale.amount,
        'commission': sale.commission,
        'payment_method': sale.paymentMethod,
        'sale_date': sale.saleDate.toIso8601String(),
      };

  Map<String, dynamic> _expenseToJson(Expense expense) => {
        'category': expense.category,
        'description': expense.description,
        'amount': expense.amount,
        'site_id': expense.siteId,
        'expense_date': expense.expenseDate.toIso8601String(),
      };

  Map<String, dynamic> _assetToJson(Asset asset) => {
        'name': asset.name,
        'type': asset.type,
        'serial_number': asset.serialNumber,
        'model': asset.model,
        'site_id': asset.siteId,
        'condition': asset.condition,
      };

  Map<String, dynamic> _maintenanceToJson(MaintenanceData maintenance) => {
        'title': maintenance.title,
        'description': maintenance.description,
        'priority': maintenance.priority,
        'status': maintenance.status,
        'site_id': maintenance.siteId,
        'asset_id': maintenance.assetId,
      };

  Map<String, dynamic> _smsLogToJson(SmsLog smsLog) => {
        'recipient': smsLog.recipient,
        'message': smsLog.message,
        'status': smsLog.status,
        'type': smsLog.type,
        'client_id': smsLog.clientId,
      };

  // Cleanup
  void dispose() {
    stopAutoSync();
  }
}

class SyncResult {
  final bool success;
  final String message;

  SyncResult({required this.success, required this.message});
}

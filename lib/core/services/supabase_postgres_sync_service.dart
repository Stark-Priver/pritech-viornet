import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

/// Supabase PostgreSQL Sync Service
/// - Uses Supabase as cloud PostgreSQL database (NO auth)
/// - Local authentication only
/// - Syncs changed records only (not entire database)
/// - Offline-first: all operations work locally first
/// - Smart conflict resolution using timestamps
class SupabaseSyncService {
  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  SupabaseClient? _client;
  AppDatabase? _db;

  /// Set the database instance (call this once from provider)
  void setDatabase(AppDatabase database) {
    _db = database;
  }

  /// Initialize Supabase (call in main.dart)
  /// Use SERVICE ROLE KEY (not anon key) since we're not using Supabase Auth
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseServiceKey, // SERVICE ROLE key, not anon
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseServiceKey, // Actually service role key
    );
    debugPrint('✅ Supabase initialized (PostgreSQL mode - no auth)');
  }

  /// Get Supabase client
  SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  /// Get database instance
  AppDatabase get db {
    if (_db == null) {
      throw Exception('❌ Database not set. Call setDatabase() first.');
    }
    return _db!;
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Full bi-directional sync
  /// 1. Push local changes to cloud
  /// 2. Pull cloud changes to local
  Future<SyncResult> syncAll() async {
    try {
      debugPrint('🔄 Starting full sync...');

      // Fix existing users without server_id before syncing
      await _ensureUsersHaveServerId();

      final pushResult = await pushToCloud();
      final pullResult = await pullFromCloud();

      return SyncResult(
        pushed: pushResult.pushed,
        pulled: pullResult.pulled,
        conflicts: pullResult.conflicts,
        errors: [...pushResult.errors, ...pullResult.errors],
      );
    } catch (e) {
      debugPrint('❌ Sync failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  /// Push local unsynced changes to cloud
  Future<SyncResult> pushToCloud() async {
    try {
      debugPrint('📤 Pushing local changes to cloud...');
      int totalPushed = 0;

      // Push each table
      totalPushed += await _pushUsers();
      totalPushed += await _pushSites();
      totalPushed += await _pushClients();
      totalPushed += await _pushVouchers();
      totalPushed += await _pushSales();
      totalPushed += await _pushExpenses();
      totalPushed += await _pushAssets();
      totalPushed += await _pushMaintenance();
      totalPushed += await _pushSmsLogs();
      totalPushed += await _pushSmsTemplates();
      totalPushed += await _pushPackages();
      totalPushed += await _pushRoles();
      totalPushed += await _pushUserRoles();

      debugPrint('✅ Pushed $totalPushed records to cloud');
      return SyncResult(pushed: totalPushed);
    } catch (e) {
      debugPrint('❌ Push failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  /// Pull cloud changes to local
  Future<SyncResult> pullFromCloud() async {
    try {
      debugPrint('📥 Pulling changes from cloud...');
      int totalPulled = 0;
      int conflicts = 0;

      // Get last sync timestamp from local
      final lastSync = await _getLastSyncTimestamp();
      debugPrint('📅 Last sync: ${lastSync ?? 'Never'}');

      // Pull each table
      final userResult = await _pullUsers(lastSync);
      totalPulled += userResult.pulled;
      conflicts += userResult.conflicts;

      final siteResult = await _pullSites(lastSync);
      totalPulled += siteResult.pulled;
      conflicts += siteResult.conflicts;

      final clientResult = await _pullClients(lastSync);
      totalPulled += clientResult.pulled;
      conflicts += clientResult.conflicts;

      final voucherResult = await _pullVouchers(lastSync);
      totalPulled += voucherResult.pulled;
      conflicts += voucherResult.conflicts;

      final saleResult = await _pullSales(lastSync);
      totalPulled += saleResult.pulled;
      conflicts += saleResult.conflicts;

      final expenseResult = await _pullExpenses(lastSync);
      totalPulled += expenseResult.pulled;
      conflicts += expenseResult.conflicts;

      final assetResult = await _pullAssets(lastSync);
      totalPulled += assetResult.pulled;
      conflicts += assetResult.conflicts;

      final maintenanceResult = await _pullMaintenance(lastSync);
      totalPulled += maintenanceResult.pulled;
      conflicts += maintenanceResult.conflicts;

      final smsLogResult = await _pullSmsLogs(lastSync);
      totalPulled += smsLogResult.pulled;
      conflicts += smsLogResult.conflicts;

      final smsTemplateResult = await _pullSmsTemplates(lastSync);
      totalPulled += smsTemplateResult.pulled;
      conflicts += smsTemplateResult.conflicts;

      final packageResult = await _pullPackages(lastSync);
      totalPulled += packageResult.pulled;
      conflicts += packageResult.conflicts;

      final roleResult = await _pullRoles(lastSync);
      totalPulled += roleResult.pulled;
      conflicts += roleResult.conflicts;

      final userRoleResult = await _pullUserRoles(lastSync);
      totalPulled += userRoleResult.pulled;
      conflicts += userRoleResult.conflicts;

      // Update last sync timestamp
      await _updateLastSyncTimestamp();

      debugPrint('✅ Pulled $totalPulled records from cloud');
      if (conflicts > 0) {
        debugPrint('⚠️  $conflicts conflicts resolved (server wins)');
      }

      return SyncResult(pulled: totalPulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  // ============================================================================
  // PUSH METHODS (Local → Cloud)
  // ============================================================================

  Future<int> _pushUsers() async {
    // Get unsynced users from local
    final unsyncedUsers = await (db.select(db.users)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedUsers.isEmpty) return 0;

    debugPrint('📤 Pushing ${unsyncedUsers.length} users...');

    for (final user in unsyncedUsers) {
      try {
        final data = {
          'server_id': user.serverId ?? _generateUUID(),
          'name': user.name,
          'email': user.email,
          'phone': user.phone,
          'role': user.role,
          'password_hash': user.passwordHash,
          'is_active': user.isActive,
          'created_at': user.createdAt.toIso8601String(),
          'updated_at': user.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (user.serverId != null) {
          // Update existing
          await client
              .from('users')
              .update(data)
              .eq('server_id', user.serverId!);
        } else {
          // Insert new
          await client.from('users').insert(data);

          // Update local with server_id
          await (db.update(db.users)..where((tbl) => tbl.id.equals(user.id)))
              .write(
                  UsersCompanion(serverId: Value(data['server_id'] as String)));
        }

        // Mark as synced
        await (db.update(db.users)..where((tbl) => tbl.id.equals(user.id)))
            .write(UsersCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push user ${user.email}: $e');
      }
    }

    return unsyncedUsers.length;
  }

  Future<int> _pushSites() async {
    final unsyncedSites = await (db.select(db.sites)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedSites.isEmpty) return 0;

    debugPrint('📤 Pushing ${unsyncedSites.length} sites...');

    for (final site in unsyncedSites) {
      try {
        final data = {
          'server_id': site.serverId ?? _generateUUID(),
          'name': site.name,
          'location': site.location,
          'gps_coordinates': site.gpsCoordinates,
          'router_ip': site.routerIp,
          'router_username': site.routerUsername,
          'router_password': site.routerPassword,
          'contact_person': site.contactPerson,
          'contact_phone': site.contactPhone,
          'is_active': site.isActive,
          'created_at': site.createdAt.toIso8601String(),
          'updated_at': site.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (site.serverId != null) {
          await client
              .from('sites')
              .update(data)
              .eq('server_id', site.serverId!);
        } else {
          await client.from('sites').insert(data);
          await (db.update(db.sites)..where((tbl) => tbl.id.equals(site.id)))
              .write(
                  SitesCompanion(serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.sites)..where((tbl) => tbl.id.equals(site.id)))
            .write(SitesCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push site ${site.name}: $e');
      }
    }

    return unsyncedSites.length;
  }

  Future<int> _pushClients() async {
    final unsyncedClients = await (db.select(db.clients)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedClients.isEmpty) return 0;

    debugPrint('📤 Pushing ${unsyncedClients.length} clients...');

    for (final client in unsyncedClients) {
      try {
        final data = {
          'server_id': client.serverId ?? _generateUUID(),
          'name': client.name,
          'phone': client.phone,
          'email': client.email,
          'mac_address': client.macAddress,
          'site_id': client.siteId,
          'address': client.address,
          'registration_date': client.registrationDate.toIso8601String(),
          'last_purchase_date': client.lastPurchaseDate?.toIso8601String(),
          'expiry_date': client.expiryDate?.toIso8601String(),
          'is_active': client.isActive,
          'sms_reminder': client.smsReminder,
          'notes': client.notes,
          'created_at': client.createdAt.toIso8601String(),
          'updated_at': client.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (client.serverId != null) {
          await this
              .client
              .from('clients')
              .update(data)
              .eq('server_id', client.serverId!);
        } else {
          await this.client.from('clients').insert(data);
          await (db.update(db.clients)
                ..where((tbl) => tbl.id.equals(client.id)))
              .write(ClientsCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.clients)..where((tbl) => tbl.id.equals(client.id)))
            .write(ClientsCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push client ${client.name}: $e');
      }
    }

    return unsyncedClients.length;
  }

  Future<int> _pushVouchers() async {
    final unsyncedVouchers = await (db.select(db.vouchers)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedVouchers.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedVouchers.length} vouchers...');

    for (final voucher in unsyncedVouchers) {
      try {
        final data = {
          'server_id': voucher.serverId ?? _generateUUID(),
          'code': voucher.code,
          'username': voucher.username,
          'password': voucher.password,
          'duration': voucher.duration,
          'price': voucher.price,
          'status': voucher.status,
          'site_id': voucher.siteId,
          'agent_id': voucher.agentId,
          'client_id': voucher.clientId,
          'created_at': voucher.createdAt.toIso8601String(),
          'sold_at': voucher.soldAt?.toIso8601String(),
          'activated_at': voucher.activatedAt?.toIso8601String(),
          'expires_at': voucher.expiresAt?.toIso8601String(),
          'updated_at': voucher.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (voucher.serverId != null) {
          await client
              .from('vouchers')
              .update(data)
              .eq('server_id', voucher.serverId!);
        } else {
          await client.from('vouchers').insert(data);
          await (db.update(db.vouchers)
                ..where((tbl) => tbl.id.equals(voucher.id)))
              .write(VouchersCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.vouchers)
              ..where((tbl) => tbl.id.equals(voucher.id)))
            .write(VouchersCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push voucher ${voucher.code}: $e');
      }
    }
    return unsyncedVouchers.length;
  }

  Future<int> _pushSales() async {
    final unsyncedSales = await (db.select(db.sales)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedSales.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedSales.length} sales...');

    for (final sale in unsyncedSales) {
      try {
        final data = {
          'server_id': sale.serverId ?? _generateUUID(),
          'receipt_number': sale.receiptNumber,
          'voucher_id': sale.voucherId,
          'client_id': sale.clientId,
          'agent_id': sale.agentId,
          'site_id': sale.siteId,
          'amount': sale.amount,
          'commission': sale.commission,
          'payment_method': sale.paymentMethod,
          'notes': sale.notes,
          'sale_date': sale.saleDate.toIso8601String(),
          'created_at': sale.createdAt.toIso8601String(),
          'updated_at': sale.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (sale.serverId != null) {
          await client
              .from('sales')
              .update(data)
              .eq('server_id', sale.serverId!);
        } else {
          await client.from('sales').insert(data);
          await (db.update(db.sales)..where((tbl) => tbl.id.equals(sale.id)))
              .write(
                  SalesCompanion(serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.sales)..where((tbl) => tbl.id.equals(sale.id)))
            .write(SalesCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push sale ${sale.receiptNumber}: $e');
      }
    }
    return unsyncedSales.length;
  }

  Future<int> _pushExpenses() async {
    final unsyncedExpenses = await (db.select(db.expenses)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedExpenses.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedExpenses.length} expenses...');

    for (final expense in unsyncedExpenses) {
      try {
        final data = {
          'server_id': expense.serverId ?? _generateUUID(),
          'category': expense.category,
          'description': expense.description,
          'amount': expense.amount,
          'site_id': expense.siteId,
          'created_by': expense.createdBy,
          'expense_date': expense.expenseDate.toIso8601String(),
          'receipt_number': expense.receiptNumber,
          'notes': expense.notes,
          'created_at': expense.createdAt.toIso8601String(),
          'updated_at': expense.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (expense.serverId != null) {
          await client
              .from('expenses')
              .update(data)
              .eq('server_id', expense.serverId!);
        } else {
          await client.from('expenses').insert(data);
          await (db.update(db.expenses)
                ..where((tbl) => tbl.id.equals(expense.id)))
              .write(ExpensesCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.expenses)
              ..where((tbl) => tbl.id.equals(expense.id)))
            .write(ExpensesCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push expense ${expense.description}: $e');
      }
    }
    return unsyncedExpenses.length;
  }

  Future<int> _pushAssets() async {
    final unsyncedAssets = await (db.select(db.assets)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedAssets.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedAssets.length} assets...');

    for (final asset in unsyncedAssets) {
      try {
        final data = {
          'server_id': asset.serverId ?? _generateUUID(),
          'name': asset.name,
          'type': asset.type,
          'serial_number': asset.serialNumber,
          'model': asset.model,
          'manufacturer': asset.manufacturer,
          'site_id': asset.siteId,
          'purchase_date': asset.purchaseDate?.toIso8601String(),
          'purchase_price': asset.purchasePrice,
          'warranty_expiry': asset.warrantyExpiry?.toIso8601String(),
          'condition': asset.condition,
          'location': asset.location,
          'notes': asset.notes,
          'is_active': asset.isActive,
          'created_at': asset.createdAt.toIso8601String(),
          'updated_at': asset.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (asset.serverId != null) {
          await client
              .from('assets')
              .update(data)
              .eq('server_id', asset.serverId!);
        } else {
          await client.from('assets').insert(data);
          await (db.update(db.assets)..where((tbl) => tbl.id.equals(asset.id)))
              .write(AssetsCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.assets)..where((tbl) => tbl.id.equals(asset.id)))
            .write(AssetsCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push asset ${asset.name}: $e');
      }
    }
    return unsyncedAssets.length;
  }

  Future<int> _pushMaintenance() async {
    final unsyncedMaintenance = await (db.select(db.maintenance)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedMaintenance.isEmpty) return 0;
    debugPrint(
        '📤 Pushing ${unsyncedMaintenance.length} maintenance records...');

    for (final maint in unsyncedMaintenance) {
      try {
        final data = {
          'server_id': maint.serverId ?? _generateUUID(),
          'title': maint.title,
          'description': maint.description,
          'priority': maint.priority,
          'status': maint.status,
          'site_id': maint.siteId,
          'asset_id': maint.assetId,
          'reported_by': maint.reportedBy,
          'assigned_to': maint.assignedTo,
          'reported_date': maint.reportedDate.toIso8601String(),
          'scheduled_date': maint.scheduledDate?.toIso8601String(),
          'completed_date': maint.completedDate?.toIso8601String(),
          'cost': maint.cost,
          'resolution': maint.resolution,
          'notes': maint.notes,
          'created_at': maint.createdAt.toIso8601String(),
          'updated_at': maint.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (maint.serverId != null) {
          await client
              .from('maintenance')
              .update(data)
              .eq('server_id', maint.serverId!);
        } else {
          await client.from('maintenance').insert(data);
          await (db.update(db.maintenance)
                ..where((tbl) => tbl.id.equals(maint.id)))
              .write(MaintenanceCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.maintenance)
              ..where((tbl) => tbl.id.equals(maint.id)))
            .write(MaintenanceCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push maintenance ${maint.title}: $e');
      }
    }
    return unsyncedMaintenance.length;
  }

  Future<int> _pushSmsLogs() async {
    final unsyncedLogs = await (db.select(db.smsLogs)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedLogs.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedLogs.length} SMS logs...');

    for (final log in unsyncedLogs) {
      try {
        final data = {
          'server_id': log.serverId ?? _generateUUID(),
          'recipient': log.recipient,
          'message': log.message,
          'status': log.status,
          'type': log.type,
          'client_id': log.clientId,
          'scheduled_at': log.scheduledAt?.toIso8601String(),
          'sent_at': log.sentAt?.toIso8601String(),
          'error_message': log.errorMessage,
          'created_at': log.createdAt.toIso8601String(),
          'updated_at': log.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (log.serverId != null) {
          await client
              .from('sms_logs')
              .update(data)
              .eq('server_id', log.serverId!);
        } else {
          await client.from('sms_logs').insert(data);
          await (db.update(db.smsLogs)..where((tbl) => tbl.id.equals(log.id)))
              .write(SmsLogsCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.smsLogs)..where((tbl) => tbl.id.equals(log.id)))
            .write(SmsLogsCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push SMS log ${log.recipient}: $e');
      }
    }
    return unsyncedLogs.length;
  }

  Future<int> _pushSmsTemplates() async {
    final unsyncedTemplates = await (db.select(db.smsTemplates)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedTemplates.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedTemplates.length} SMS templates...');

    for (final template in unsyncedTemplates) {
      try {
        final data = {
          'server_id': template.serverId ?? _generateUUID(),
          'name': template.name,
          'message': template.message,
          'type': template.type,
          'is_active': template.isActive,
          'created_at': template.createdAt.toIso8601String(),
          'updated_at': template.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (template.serverId != null) {
          await client
              .from('sms_templates')
              .update(data)
              .eq('server_id', template.serverId!);
        } else {
          await client.from('sms_templates').insert(data);
          await (db.update(db.smsTemplates)
                ..where((tbl) => tbl.id.equals(template.id)))
              .write(SmsTemplatesCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.smsTemplates)
              ..where((tbl) => tbl.id.equals(template.id)))
            .write(SmsTemplatesCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push SMS template ${template.name}: $e');
      }
    }
    return unsyncedTemplates.length;
  }

  Future<int> _pushPackages() async {
    final unsyncedPackages = await (db.select(db.packages)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    if (unsyncedPackages.isEmpty) return 0;
    debugPrint('📤 Pushing ${unsyncedPackages.length} packages...');

    for (final package in unsyncedPackages) {
      try {
        final data = {
          'server_id': package.serverId ?? _generateUUID(),
          'name': package.name,
          'duration': package.duration,
          'price': package.price,
          'description': package.description,
          'is_active': package.isActive,
          'created_at': package.createdAt.toIso8601String(),
          'updated_at': package.updatedAt.toIso8601String(),
          'is_synced': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        };

        if (package.serverId != null) {
          await client
              .from('packages')
              .update(data)
              .eq('server_id', package.serverId!);
        } else {
          await client.from('packages').insert(data);
          await (db.update(db.packages)
                ..where((tbl) => tbl.id.equals(package.id)))
              .write(PackagesCompanion(
                  serverId: Value(data['server_id'] as String)));
        }

        await (db.update(db.packages)
              ..where((tbl) => tbl.id.equals(package.id)))
            .write(PackagesCompanion(
          isSynced: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('❌ Failed to push package ${package.name}: $e');
      }
    }
    return unsyncedPackages.length;
  }

  // ============================================================================
  // PULL METHODS (Cloud → Local)
  // ============================================================================

  Future<SyncResult> _pullUsers(DateTime? lastSync) async {
    try {
      // Query cloud for changes since lastSync
      var query = client.from('users').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudUsers = await query;
      if (cloudUsers.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudUsers.length} users from cloud...');

      int pulled = 0;
      int conflicts = 0;

      for (final userData in cloudUsers) {
        try {
          final cloudServerId = userData['server_id'] as String;
          final cloudEmail = userData['email'] as String;

          // Check if user exists locally by server_id OR email
          var existing = await (db.select(db.users)
                ..where((tbl) => tbl.serverId.equals(cloudServerId)))
              .getSingleOrNull();

          // If not found by server_id, try by email
          existing ??= await (db.select(db.users)
                ..where((tbl) => tbl.email.equals(cloudEmail)))
              .getSingleOrNull();

          final existingUser = existing;
          if (existingUser != null) {
            // Check for conflict (both modified since last sync)
            if (existingUser.isSynced == false) {
              // Conflict! Server wins
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on user ${existingUser.email} - server wins');
            }

            // Update existing record (including server_id if missing)
            await (db.update(db.users)
                  ..where((tbl) => tbl.id.equals(existingUser.id)))
                .write(UsersCompanion(
              serverId: Value(cloudServerId), // Update server_id
              name: Value(userData['name']),
              email: Value(userData['email']),
              phone: Value(userData['phone']),
              role: Value(userData['role']),
              passwordHash: Value(userData['password_hash']),
              isActive: Value(userData['is_active']),
              updatedAt: Value(DateTime.parse(userData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
            debugPrint('✅ Updated user: ${existingUser.email}');
          } else {
            // Insert new record
            await db.into(db.users).insert(UsersCompanion(
                  serverId: Value(cloudServerId),
                  name: Value(userData['name']),
                  email: Value(userData['email']),
                  phone: Value(userData['phone']),
                  role: Value(userData['role']),
                  passwordHash: Value(userData['password_hash']),
                  isActive: Value(userData['is_active']),
                  createdAt: Value(DateTime.parse(userData['created_at'])),
                  updatedAt: Value(DateTime.parse(userData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
            debugPrint('✅ Inserted new user: $cloudEmail');
          }

          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull user: $e');
        }
      }

      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull users failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullSites(DateTime? lastSync) async {
    try {
      var query = client.from('sites').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudSites = await query;
      if (cloudSites.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudSites.length} sites from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final siteData in cloudSites) {
        try {
          final existing = await (db.select(db.sites)
                ..where((tbl) =>
                    tbl.serverId.equals(siteData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint('⚠️  Conflict on site ${existing.name} - server wins');
            }

            await (db.update(db.sites)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(SitesCompanion(
              name: Value(siteData['name']),
              location: Value(siteData['location']),
              gpsCoordinates: Value(siteData['gps_coordinates']),
              routerIp: Value(siteData['router_ip']),
              routerUsername: Value(siteData['router_username']),
              routerPassword: Value(siteData['router_password']),
              contactPerson: Value(siteData['contact_person']),
              contactPhone: Value(siteData['contact_phone']),
              isActive: Value(siteData['is_active']),
              updatedAt: Value(DateTime.parse(siteData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.sites).insert(SitesCompanion(
                  serverId: Value(siteData['server_id']),
                  name: Value(siteData['name']),
                  location: Value(siteData['location']),
                  gpsCoordinates: Value(siteData['gps_coordinates']),
                  routerIp: Value(siteData['router_ip']),
                  routerUsername: Value(siteData['router_username']),
                  routerPassword: Value(siteData['router_password']),
                  contactPerson: Value(siteData['contact_person']),
                  contactPhone: Value(siteData['contact_phone']),
                  isActive: Value(siteData['is_active']),
                  createdAt: Value(DateTime.parse(siteData['created_at'])),
                  updatedAt: Value(DateTime.parse(siteData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull site: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull sites failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullClients(DateTime? lastSync) async {
    try {
      var query = client.from('clients').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudClients = await query;
      if (cloudClients.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudClients.length} clients from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final clientData in cloudClients) {
        try {
          final existing = await (db.select(db.clients)
                ..where((tbl) =>
                    tbl.serverId.equals(clientData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on client ${existing.name} - server wins');
            }

            await (db.update(db.clients)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(ClientsCompanion(
              name: Value(clientData['name']),
              phone: Value(clientData['phone']),
              email: Value(clientData['email']),
              macAddress: Value(clientData['mac_address']),
              siteId: Value(clientData['site_id']),
              address: Value(clientData['address']),
              registrationDate:
                  Value(DateTime.parse(clientData['registration_date'])),
              lastPurchaseDate: clientData['last_purchase_date'] != null
                  ? Value(DateTime.parse(clientData['last_purchase_date']))
                  : const Value(null),
              expiryDate: clientData['expiry_date'] != null
                  ? Value(DateTime.parse(clientData['expiry_date']))
                  : const Value(null),
              isActive: Value(clientData['is_active']),
              smsReminder: Value(clientData['sms_reminder']),
              notes: Value(clientData['notes']),
              updatedAt: Value(DateTime.parse(clientData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.clients).insert(ClientsCompanion(
                  serverId: Value(clientData['server_id']),
                  name: Value(clientData['name']),
                  phone: Value(clientData['phone']),
                  email: Value(clientData['email']),
                  macAddress: Value(clientData['mac_address']),
                  siteId: Value(clientData['site_id']),
                  address: Value(clientData['address']),
                  registrationDate:
                      Value(DateTime.parse(clientData['registration_date'])),
                  lastPurchaseDate: clientData['last_purchase_date'] != null
                      ? Value(DateTime.parse(clientData['last_purchase_date']))
                      : const Value(null),
                  expiryDate: clientData['expiry_date'] != null
                      ? Value(DateTime.parse(clientData['expiry_date']))
                      : const Value(null),
                  isActive: Value(clientData['is_active']),
                  smsReminder: Value(clientData['sms_reminder']),
                  notes: Value(clientData['notes']),
                  createdAt: Value(DateTime.parse(clientData['created_at'])),
                  updatedAt: Value(DateTime.parse(clientData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull client: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull clients failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullVouchers(DateTime? lastSync) async {
    try {
      var query = client.from('vouchers').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudVouchers = await query;
      if (cloudVouchers.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudVouchers.length} vouchers from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final voucherData in cloudVouchers) {
        try {
          final existing = await (db.select(db.vouchers)
                ..where((tbl) =>
                    tbl.serverId.equals(voucherData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on voucher ${existing.code} - server wins');
            }

            await (db.update(db.vouchers)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(VouchersCompanion(
              code: Value(voucherData['code']),
              username: Value(voucherData['username']),
              password: Value(voucherData['password']),
              duration: Value(voucherData['duration']),
              price: Value(voucherData['price']),
              status: Value(voucherData['status']),
              siteId: Value(voucherData['site_id']),
              agentId: Value(voucherData['agent_id']),
              clientId: Value(voucherData['client_id']),
              soldAt: voucherData['sold_at'] != null
                  ? Value(DateTime.parse(voucherData['sold_at']))
                  : const Value(null),
              activatedAt: voucherData['activated_at'] != null
                  ? Value(DateTime.parse(voucherData['activated_at']))
                  : const Value(null),
              expiresAt: voucherData['expires_at'] != null
                  ? Value(DateTime.parse(voucherData['expires_at']))
                  : const Value(null),
              updatedAt: Value(DateTime.parse(voucherData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.vouchers).insert(VouchersCompanion(
                  serverId: Value(voucherData['server_id']),
                  code: Value(voucherData['code']),
                  username: Value(voucherData['username']),
                  password: Value(voucherData['password']),
                  duration: Value(voucherData['duration']),
                  price: Value(voucherData['price']),
                  status: Value(voucherData['status']),
                  siteId: Value(voucherData['site_id']),
                  agentId: Value(voucherData['agent_id']),
                  clientId: Value(voucherData['client_id']),
                  createdAt: Value(DateTime.parse(voucherData['created_at'])),
                  soldAt: voucherData['sold_at'] != null
                      ? Value(DateTime.parse(voucherData['sold_at']))
                      : const Value(null),
                  activatedAt: voucherData['activated_at'] != null
                      ? Value(DateTime.parse(voucherData['activated_at']))
                      : const Value(null),
                  expiresAt: voucherData['expires_at'] != null
                      ? Value(DateTime.parse(voucherData['expires_at']))
                      : const Value(null),
                  updatedAt: Value(DateTime.parse(voucherData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull voucher: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull vouchers failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullSales(DateTime? lastSync) async {
    try {
      var query = client.from('sales').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudSales = await query;
      if (cloudSales.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudSales.length} sales from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final saleData in cloudSales) {
        try {
          final existing = await (db.select(db.sales)
                ..where((tbl) =>
                    tbl.serverId.equals(saleData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on sale ${existing.receiptNumber} - server wins');
            }

            await (db.update(db.sales)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(SalesCompanion(
              receiptNumber: Value(saleData['receipt_number']),
              voucherId: Value(saleData['voucher_id']),
              clientId: Value(saleData['client_id']),
              agentId: Value(saleData['agent_id']),
              siteId: Value(saleData['site_id']),
              amount: Value(saleData['amount']),
              commission: Value(saleData['commission']),
              paymentMethod: Value(saleData['payment_method']),
              notes: Value(saleData['notes']),
              saleDate: Value(DateTime.parse(saleData['sale_date'])),
              updatedAt: Value(DateTime.parse(saleData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.sales).insert(SalesCompanion(
                  serverId: Value(saleData['server_id']),
                  receiptNumber: Value(saleData['receipt_number']),
                  voucherId: Value(saleData['voucher_id']),
                  clientId: Value(saleData['client_id']),
                  agentId: Value(saleData['agent_id']),
                  siteId: Value(saleData['site_id']),
                  amount: Value(saleData['amount']),
                  commission: Value(saleData['commission']),
                  paymentMethod: Value(saleData['payment_method']),
                  notes: Value(saleData['notes']),
                  saleDate: Value(DateTime.parse(saleData['sale_date'])),
                  createdAt: Value(DateTime.parse(saleData['created_at'])),
                  updatedAt: Value(DateTime.parse(saleData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull sale: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull sales failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullExpenses(DateTime? lastSync) async {
    try {
      var query = client.from('expenses').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudExpenses = await query;
      if (cloudExpenses.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudExpenses.length} expenses from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final expenseData in cloudExpenses) {
        try {
          final existing = await (db.select(db.expenses)
                ..where((tbl) =>
                    tbl.serverId.equals(expenseData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint('⚠️  Conflict on expense - server wins');
            }

            await (db.update(db.expenses)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(ExpensesCompanion(
              category: Value(expenseData['category']),
              description: Value(expenseData['description']),
              amount: Value(expenseData['amount']),
              siteId: Value(expenseData['site_id']),
              createdBy: Value(expenseData['created_by']),
              expenseDate: Value(DateTime.parse(expenseData['expense_date'])),
              receiptNumber: Value(expenseData['receipt_number']),
              notes: Value(expenseData['notes']),
              updatedAt: Value(DateTime.parse(expenseData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.expenses).insert(ExpensesCompanion(
                  serverId: Value(expenseData['server_id']),
                  category: Value(expenseData['category']),
                  description: Value(expenseData['description']),
                  amount: Value(expenseData['amount']),
                  siteId: Value(expenseData['site_id']),
                  createdBy: Value(expenseData['created_by']),
                  expenseDate:
                      Value(DateTime.parse(expenseData['expense_date'])),
                  receiptNumber: Value(expenseData['receipt_number']),
                  notes: Value(expenseData['notes']),
                  createdAt: Value(DateTime.parse(expenseData['created_at'])),
                  updatedAt: Value(DateTime.parse(expenseData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull expense: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull expenses failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullAssets(DateTime? lastSync) async {
    try {
      var query = client.from('assets').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudAssets = await query;
      if (cloudAssets.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudAssets.length} assets from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final assetData in cloudAssets) {
        try {
          final existing = await (db.select(db.assets)
                ..where((tbl) =>
                    tbl.serverId.equals(assetData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on asset ${existing.name} - server wins');
            }

            await (db.update(db.assets)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(AssetsCompanion(
              name: Value(assetData['name']),
              type: Value(assetData['type']),
              serialNumber: Value(assetData['serial_number']),
              model: Value(assetData['model']),
              manufacturer: Value(assetData['manufacturer']),
              siteId: Value(assetData['site_id']),
              purchaseDate: assetData['purchase_date'] != null
                  ? Value(DateTime.parse(assetData['purchase_date']))
                  : const Value(null),
              purchasePrice: Value(assetData['purchase_price']),
              warrantyExpiry: assetData['warranty_expiry'] != null
                  ? Value(DateTime.parse(assetData['warranty_expiry']))
                  : const Value(null),
              condition: Value(assetData['condition']),
              location: Value(assetData['location']),
              notes: Value(assetData['notes']),
              isActive: Value(assetData['is_active']),
              updatedAt: Value(DateTime.parse(assetData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.assets).insert(AssetsCompanion(
                  serverId: Value(assetData['server_id']),
                  name: Value(assetData['name']),
                  type: Value(assetData['type']),
                  serialNumber: Value(assetData['serial_number']),
                  model: Value(assetData['model']),
                  manufacturer: Value(assetData['manufacturer']),
                  siteId: Value(assetData['site_id']),
                  purchaseDate: assetData['purchase_date'] != null
                      ? Value(DateTime.parse(assetData['purchase_date']))
                      : const Value(null),
                  purchasePrice: Value(assetData['purchase_price']),
                  warrantyExpiry: assetData['warranty_expiry'] != null
                      ? Value(DateTime.parse(assetData['warranty_expiry']))
                      : const Value(null),
                  condition: Value(assetData['condition']),
                  location: Value(assetData['location']),
                  notes: Value(assetData['notes']),
                  isActive: Value(assetData['is_active']),
                  createdAt: Value(DateTime.parse(assetData['created_at'])),
                  updatedAt: Value(DateTime.parse(assetData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull asset: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull assets failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullMaintenance(DateTime? lastSync) async {
    try {
      var query = client.from('maintenance').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudMaintenance = await query;
      if (cloudMaintenance.isEmpty) return SyncResult();

      debugPrint(
          '📥 Pulling ${cloudMaintenance.length} maintenance records from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final maintData in cloudMaintenance) {
        try {
          final existing = await (db.select(db.maintenance)
                ..where((tbl) =>
                    tbl.serverId.equals(maintData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on maintenance ${existing.title} - server wins');
            }

            await (db.update(db.maintenance)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(MaintenanceCompanion(
              title: Value(maintData['title']),
              description: Value(maintData['description']),
              priority: Value(maintData['priority']),
              status: Value(maintData['status']),
              siteId: Value(maintData['site_id']),
              assetId: Value(maintData['asset_id']),
              reportedBy: Value(maintData['reported_by']),
              assignedTo: Value(maintData['assigned_to']),
              reportedDate: Value(DateTime.parse(maintData['reported_date'])),
              scheduledDate: maintData['scheduled_date'] != null
                  ? Value(DateTime.parse(maintData['scheduled_date']))
                  : const Value(null),
              completedDate: maintData['completed_date'] != null
                  ? Value(DateTime.parse(maintData['completed_date']))
                  : const Value(null),
              cost: Value(maintData['cost']),
              resolution: Value(maintData['resolution']),
              notes: Value(maintData['notes']),
              updatedAt: Value(DateTime.parse(maintData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.maintenance).insert(MaintenanceCompanion(
                  serverId: Value(maintData['server_id']),
                  title: Value(maintData['title']),
                  description: Value(maintData['description']),
                  priority: Value(maintData['priority']),
                  status: Value(maintData['status']),
                  siteId: Value(maintData['site_id']),
                  assetId: Value(maintData['asset_id']),
                  reportedBy: Value(maintData['reported_by']),
                  assignedTo: Value(maintData['assigned_to']),
                  reportedDate:
                      Value(DateTime.parse(maintData['reported_date'])),
                  scheduledDate: maintData['scheduled_date'] != null
                      ? Value(DateTime.parse(maintData['scheduled_date']))
                      : const Value(null),
                  completedDate: maintData['completed_date'] != null
                      ? Value(DateTime.parse(maintData['completed_date']))
                      : const Value(null),
                  cost: Value(maintData['cost']),
                  resolution: Value(maintData['resolution']),
                  notes: Value(maintData['notes']),
                  createdAt: Value(DateTime.parse(maintData['created_at'])),
                  updatedAt: Value(DateTime.parse(maintData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull maintenance: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull maintenance failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullSmsLogs(DateTime? lastSync) async {
    try {
      var query = client.from('sms_logs').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudLogs = await query;
      if (cloudLogs.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudLogs.length} SMS logs from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final logData in cloudLogs) {
        try {
          final existing = await (db.select(db.smsLogs)
                ..where((tbl) =>
                    tbl.serverId.equals(logData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint('⚠️  Conflict on SMS log - server wins');
            }

            await (db.update(db.smsLogs)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(SmsLogsCompanion(
              recipient: Value(logData['recipient']),
              message: Value(logData['message']),
              status: Value(logData['status']),
              type: Value(logData['type']),
              clientId: Value(logData['client_id']),
              scheduledAt: logData['scheduled_at'] != null
                  ? Value(DateTime.parse(logData['scheduled_at']))
                  : const Value(null),
              sentAt: logData['sent_at'] != null
                  ? Value(DateTime.parse(logData['sent_at']))
                  : const Value(null),
              errorMessage: Value(logData['error_message']),
              updatedAt: Value(DateTime.parse(logData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.smsLogs).insert(SmsLogsCompanion(
                  serverId: Value(logData['server_id']),
                  recipient: Value(logData['recipient']),
                  message: Value(logData['message']),
                  status: Value(logData['status']),
                  type: Value(logData['type']),
                  clientId: Value(logData['client_id']),
                  scheduledAt: logData['scheduled_at'] != null
                      ? Value(DateTime.parse(logData['scheduled_at']))
                      : const Value(null),
                  sentAt: logData['sent_at'] != null
                      ? Value(DateTime.parse(logData['sent_at']))
                      : const Value(null),
                  errorMessage: Value(logData['error_message']),
                  createdAt: Value(DateTime.parse(logData['created_at'])),
                  updatedAt: Value(DateTime.parse(logData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull SMS log: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull SMS logs failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullSmsTemplates(DateTime? lastSync) async {
    try {
      var query = client.from('sms_templates').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudTemplates = await query;
      if (cloudTemplates.isEmpty) return SyncResult();

      debugPrint(
          '📥 Pulling ${cloudTemplates.length} SMS templates from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final templateData in cloudTemplates) {
        try {
          final existing = await (db.select(db.smsTemplates)
                ..where((tbl) =>
                    tbl.serverId.equals(templateData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on SMS template ${existing.name} - server wins');
            }

            await (db.update(db.smsTemplates)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(SmsTemplatesCompanion(
              name: Value(templateData['name']),
              message: Value(templateData['message']),
              type: Value(templateData['type']),
              isActive: Value(templateData['is_active']),
              updatedAt: Value(DateTime.parse(templateData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.smsTemplates).insert(SmsTemplatesCompanion(
                  serverId: Value(templateData['server_id']),
                  name: Value(templateData['name']),
                  message: Value(templateData['message']),
                  type: Value(templateData['type']),
                  isActive: Value(templateData['is_active']),
                  createdAt: Value(DateTime.parse(templateData['created_at'])),
                  updatedAt: Value(DateTime.parse(templateData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull SMS template: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull SMS templates failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  Future<SyncResult> _pullPackages(DateTime? lastSync) async {
    try {
      var query = client.from('packages').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudPackages = await query;
      if (cloudPackages.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudPackages.length} packages from cloud...');
      int pulled = 0;
      int conflicts = 0;

      for (final packageData in cloudPackages) {
        try {
          final existing = await (db.select(db.packages)
                ..where((tbl) =>
                    tbl.serverId.equals(packageData['server_id'] as String)))
              .getSingleOrNull();

          if (existing != null) {
            if (existing.isSynced == false) {
              conflicts++;
              debugPrint(
                  '⚠️  Conflict on package ${existing.name} - server wins');
            }

            await (db.update(db.packages)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(PackagesCompanion(
              name: Value(packageData['name']),
              duration: Value(packageData['duration']),
              price: Value(packageData['price']),
              description: Value(packageData['description']),
              isActive: Value(packageData['is_active']),
              updatedAt: Value(DateTime.parse(packageData['updated_at'])),
              isSynced: const Value(true),
              lastSyncedAt: Value(DateTime.now()),
            ));
          } else {
            await db.into(db.packages).insert(PackagesCompanion(
                  serverId: Value(packageData['server_id']),
                  name: Value(packageData['name']),
                  duration: Value(packageData['duration']),
                  price: Value(packageData['price']),
                  description: Value(packageData['description']),
                  isActive: Value(packageData['is_active']),
                  createdAt: Value(DateTime.parse(packageData['created_at'])),
                  updatedAt: Value(DateTime.parse(packageData['updated_at'])),
                  isSynced: const Value(true),
                  lastSyncedAt: Value(DateTime.now()),
                ));
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull package: $e');
        }
      }
      return SyncResult(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      debugPrint('❌ Pull packages failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  // ============================================================================
  // ROLES SYNC (Reference data - no sync fields needed)
  // ============================================================================

  Future<int> _pushRoles() async {
    // Get all roles from local
    final localRoles = await db.select(db.roles).get();

    if (localRoles.isEmpty) return 0;

    debugPrint('📤 Pushing ${localRoles.length} roles...');

    for (final role in localRoles) {
      try {
        // Check if role exists in cloud
        final cloudRoles =
            await client.from('roles').select().eq('id', role.id).maybeSingle();

        final data = {
          'id': role.id,
          'name': role.name,
          'description': role.description,
          'is_active': role.isActive,
          'created_at': role.createdAt.toIso8601String(),
          'updated_at': role.updatedAt.toIso8601String(),
        };

        if (cloudRoles != null) {
          // Update existing
          await client.from('roles').update(data).eq('id', role.id);
        } else {
          // Insert new
          await client.from('roles').insert(data);
        }
      } catch (e) {
        debugPrint('❌ Failed to push role ${role.name}: $e');
      }
    }

    return localRoles.length;
  }

  Future<SyncResult> _pullRoles(DateTime? lastSync) async {
    try {
      var query = client.from('roles').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudRoles = await query;
      if (cloudRoles.isEmpty) return SyncResult();

      debugPrint('📥 Pulling ${cloudRoles.length} roles from cloud...');
      int pulled = 0;

      for (final roleData in cloudRoles) {
        try {
          final existing = await (db.select(db.roles)
                ..where((tbl) => tbl.id.equals(roleData['id'] as int)))
              .getSingleOrNull();

          if (existing != null) {
            await (db.update(db.roles)
                  ..where((tbl) => tbl.id.equals(existing.id)))
                .write(RolesCompanion(
              name: Value(roleData['name']),
              description: Value(roleData['description']),
              isActive: Value(roleData['is_active']),
              updatedAt: Value(DateTime.parse(roleData['updated_at'])),
            ));
          } else {
            await db.into(db.roles).insert(
                  RolesCompanion.insert(
                    id: Value(roleData['id']),
                    name: roleData['name'],
                    description: roleData['description'],
                    isActive: Value(roleData['is_active']),
                    createdAt: DateTime.parse(roleData['created_at']),
                    updatedAt: DateTime.parse(roleData['updated_at']),
                  ),
                );
          }
          pulled++;
        } catch (e) {
          debugPrint('❌ Failed to pull role: $e');
        }
      }
      return SyncResult(pulled: pulled);
    } catch (e) {
      debugPrint('❌ Pull roles failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  // ============================================================================
  // USER ROLES SYNC (Many-to-Many junction table)
  // ============================================================================

  Future<int> _pushUserRoles() async {
    // Get all user_roles with user server_id for cross-device sync
    final query = db.select(db.userRoles).join([
      leftOuterJoin(db.users, db.users.id.equalsExp(db.userRoles.userId)),
    ]);

    final results = await query.get();
    if (results.isEmpty) return 0;

    debugPrint('📤 Pushing ${results.length} user roles...');
    int pushed = 0;

    for (final row in results) {
      try {
        final userRole = row.readTable(db.userRoles);
        final user = row.readTable(db.users);

        if (user.serverId == null) {
          debugPrint('⚠️  Skipping user_role: user has no server_id');
          continue;
        }

        // Check if user_role exists in cloud (by user server_id)
        final cloudUserRoles = await client
            .from('user_roles')
            .select('*, users!inner(server_id)')
            .eq('users.server_id', user.serverId!)
            .eq('role_id', userRole.roleId)
            .maybeSingle();

        if (cloudUserRoles == null) {
          // Get cloud user_id from server_id
          final cloudUser = await client
              .from('users')
              .select('id')
              .eq('server_id', user.serverId!)
              .maybeSingle();

          if (cloudUser == null) {
            debugPrint('⚠️  User not found in cloud: ${user.serverId}');
            continue;
          }

          final data = {
            'user_id': cloudUser['id'],
            'role_id': userRole.roleId,
            'assigned_at': userRole.assignedAt.toIso8601String(),
          };

          // Insert new (no update needed for junction tables)
          await client.from('user_roles').insert(data);
          pushed++;
        }
      } catch (e) {
        debugPrint('❌ Failed to push user_role: $e');
      }
    }

    return pushed;
  }

  Future<SyncResult> _pullUserRoles(DateTime? lastSync) async {
    try {
      // Pull user_roles with user server_id for cross-device matching
      var query = client.from('user_roles').select('*, users!inner(server_id)');
      if (lastSync != null) {
        query = query.gt('assigned_at', lastSync.toIso8601String());
      }

      final List<dynamic> cloudUserRoles = await query;
      if (cloudUserRoles.isEmpty) return SyncResult();

      debugPrint(
          '📥 Pulling ${cloudUserRoles.length} user roles from cloud...');
      int pulled = 0;

      for (final userRoleData in cloudUserRoles) {
        try {
          final userServerId = userRoleData['users']['server_id'] as String;
          final roleId = userRoleData['role_id'] as int;

          // Find local user by server_id
          final localUser = await (db.select(db.users)
                ..where((tbl) => tbl.serverId.equals(userServerId)))
              .getSingleOrNull();

          if (localUser == null) {
            debugPrint('⚠️  User not found locally: $userServerId');
            continue;
          }

          // Check if user_role already exists locally
          final existing = await (db.select(db.userRoles)
                ..where((tbl) =>
                    tbl.userId.equals(localUser.id) &
                    tbl.roleId.equals(roleId)))
              .getSingleOrNull();

          if (existing == null) {
            await db.into(db.userRoles).insert(
                  UserRolesCompanion.insert(
                    userId: localUser.id,
                    roleId: roleId,
                    assignedAt: DateTime.parse(userRoleData['assigned_at']),
                  ),
                );
            pulled++;
            debugPrint('✅ Assigned role $roleId to user ${localUser.email}');
          }
        } catch (e) {
          debugPrint('❌ Failed to pull user_role: $e');
        }
      }
      return SyncResult(pulled: pulled);
    } catch (e) {
      debugPrint('❌ Pull user roles failed: $e');
      return SyncResult(errors: [e.toString()]);
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Migration: Ensure all existing users have server_id
  /// This fixes users created before the server_id requirement
  Future<void> _ensureUsersHaveServerId() async {
    try {
      // Find users without server_id
      final usersWithoutServerId = await (db.select(db.users)
            ..where((tbl) => tbl.serverId.isNull()))
          .get();

      if (usersWithoutServerId.isEmpty) return;

      debugPrint(
          '🔧 Migrating ${usersWithoutServerId.length} users without server_id...');

      for (final user in usersWithoutServerId) {
        try {
          // Generate new UUID
          final newServerId = _generateUUID();

          // Update local user
          await (db.update(db.users)..where((tbl) => tbl.id.equals(user.id)))
              .write(UsersCompanion(
            serverId: Value(newServerId),
            isSynced: const Value(false), // Mark for sync
          ));

          debugPrint('✅ Assigned server_id to user: ${user.email}');
        } catch (e) {
          debugPrint('❌ Failed to assign server_id to ${user.email}: $e');
        }
      }

      debugPrint('✅ Migration complete');
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
    }
  }

  String _generateUUID() {
    // Generate proper UUID v4 using uuid package
    const uuid = Uuid();
    return uuid.v4();
  }

  Future<DateTime?> _getLastSyncTimestamp() async {
    try {
      // Query the most recent updated_at timestamp across all synced records
      // This ensures we only pull changes newer than our latest local data
      final results = await db.customSelect(
        '''
        SELECT MAX(updated_at) as last_sync FROM (
          SELECT updated_at FROM users WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM sites WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM clients WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM vouchers WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM sales WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM expenses WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM assets WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM maintenance WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM sms_logs WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM sms_templates WHERE is_synced = 1
          UNION ALL SELECT updated_at FROM packages WHERE is_synced = 1
        )
        ''',
        readsFrom: {
          db.users,
          db.sites,
          db.clients,
          db.vouchers,
          db.sales,
          db.expenses,
          db.assets,
          db.maintenance,
          db.smsLogs,
          db.smsTemplates,
          db.packages
        },
      ).getSingle();

      final timestamp = results.data['last_sync'];
      if (timestamp == null) return null;

      // Handle both int (Unix timestamp) and String formats
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Could not get last sync timestamp: $e');
      return null;
    }
  }

  Future<void> _updateLastSyncTimestamp() async {
    // Timestamp is automatically updated via updated_at field on each record
    // No additional action needed as we track per-record sync status
  }

  /// Check connectivity to Supabase
  Future<bool> isConnected() async {
    try {
      await client.from('users').select().limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    final usersToSync = await (db.select(db.users)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    final sitesToSync = await (db.select(db.sites)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();
    final clientsToSync = await (db.select(db.clients)
          ..where((tbl) => tbl.isSynced.equals(false)))
        .get();

    final pendingChanges =
        usersToSync.length + sitesToSync.length + clientsToSync.length;

    return SyncStatus(
      pendingChanges: pendingChanges,
      lastSync: await _getLastSyncTimestamp(),
      isConnected: await isConnected(),
    );
  }
}

// ============================================================================
// DATA CLASSES
// ============================================================================

class SyncResult {
  final int pushed;
  final int pulled;
  final int conflicts;
  final List<String> errors;

  SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.errors = const [],
  });

  bool get isSuccess => errors.isEmpty;
  int get total => pushed + pulled;
}

class SyncStatus {
  final int pendingChanges;
  final DateTime? lastSync;
  final bool isConnected;

  SyncStatus({
    required this.pendingChanges,
    this.lastSync,
    required this.isConnected,
  });

  bool get hasPendingChanges => pendingChanges > 0;
}

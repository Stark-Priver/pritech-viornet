import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/secure_storage_service.dart';
import '../services/api_service.dart';
import '../services/supabase_postgres_sync_service.dart';
import '../../features/clients/repository/client_repository.dart';
import '../../features/vouchers/repository/voucher_repository.dart';
import '../../features/sales/repository/sales_repository.dart';
import '../../features/sites/repository/site_repository.dart';
import '../../features/assets/repository/asset_repository.dart';
import '../../features/maintenance/repository/maintenance_repository.dart';
import '../../features/finance/repository/expense_repository.dart';

// Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Services Providers
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  final syncService = SupabaseSyncService();
  final database = ref.watch(databaseProvider);
  syncService.setDatabase(database);
  return syncService;
});

// Repository Providers
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ClientRepository(database);
});

final voucherRepositoryProvider = Provider<VoucherRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return VoucherRepository(database);
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SalesRepository(database);
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SiteRepository(database);
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return AssetRepository(database);
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return MaintenanceRepository(database);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ExpenseRepository(database);
});

// State Providers for UI
final selectedSiteProvider = StateProvider<Site?>((ref) => null);
final selectedClientProvider = StateProvider<Client?>((ref) => null);
final selectedVoucherProvider = StateProvider<Voucher?>((ref) => null);

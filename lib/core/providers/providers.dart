import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_data_service.dart';
import '../services/secure_storage_service.dart';
import '../services/api_service.dart';
import '../services/voucher_service.dart';
import '../services/commission_service.dart';
import '../models/app_models.dart';
import '../../features/clients/repository/client_repository.dart';
import '../../features/sales/repository/sales_repository.dart';
import '../../features/sites/repository/site_repository.dart';
import '../../features/assets/repository/asset_repository.dart';
import '../../features/maintenance/repository/maintenance_repository.dart';
import '../../features/finance/repository/expense_repository.dart';

// Supabase Data Service Provider (singleton – online-only, no local DB)
final supabaseDataServiceProvider = Provider<SupabaseDataService>((ref) {
  return SupabaseDataService();
});

// Backward-compat alias so screens that still reference databaseProvider
// compile without change until they are individually migrated.
final databaseProvider = supabaseDataServiceProvider;

// Services Providers
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final voucherServiceProvider = Provider<VoucherService>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return VoucherService(service);
});

final commissionServiceProvider = Provider<CommissionService>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return CommissionService(service);
});

// Repository Providers
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return ClientRepository(service);
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return SalesRepository(service);
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return SiteRepository(service);
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return AssetRepository(service);
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return MaintenanceRepository(service);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final service = ref.watch(supabaseDataServiceProvider);
  return ExpenseRepository(service);
});

// State Providers for UI
final selectedSiteProvider = StateProvider<Site?>((ref) => null);
final selectedClientProvider = StateProvider<Client?>((ref) => null);
final selectedVoucherProvider = StateProvider<Voucher?>((ref) => null);

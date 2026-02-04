import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/constants/app_constants.dart';

class VoucherRepository {
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  VoucherRepository(this._database);

  // Generate vouchers in bulk
  Future<List<int>> generateVouchers({
    required int count,
    required int duration,
    required double price,
    int? siteId,
    int? agentId,
  }) async {
    final List<int> voucherIds = [];

    for (int i = 0; i < count; i++) {
      final code = _generateVoucherCode();
      final username = 'user_${_uuid.v4().substring(0, 8)}';
      final password = _generatePassword();

      final voucherId = await _database.into(_database.vouchers).insert(
            VouchersCompanion.insert(
              code: code,
              username: Value(username),
              password: Value(password),
              duration: duration,
              price: price,
              status: AppConstants.voucherStatusUnused,
              siteId: siteId != null ? Value(siteId) : const Value.absent(),
              agentId: agentId != null ? Value(agentId) : const Value.absent(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      voucherIds.add(voucherId);
    }

    return voucherIds;
  }

  // Create single voucher
  Future<int> createVoucher(VouchersCompanion voucher) async {
    return await _database.into(_database.vouchers).insert(voucher);
  }

  // Get all vouchers
  Future<List<Voucher>> getAllVouchers() async {
    return await _database.select(_database.vouchers).get();
  }

  // Get voucher by ID
  Future<Voucher?> getVoucherById(int id) async {
    return await (_database.select(
      _database.vouchers,
    )..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get voucher by code
  Future<Voucher?> getVoucherByCode(String code) async {
    return await (_database.select(
      _database.vouchers,
    )..where((tbl) => tbl.code.equals(code)))
        .getSingleOrNull();
  }

  // Get vouchers by status
  Future<List<Voucher>> getVouchersByStatus(String status) async {
    return await (_database.select(
      _database.vouchers,
    )..where((tbl) => tbl.status.equals(status)))
        .get();
  }

  // Get unused vouchers
  Future<List<Voucher>> getUnusedVouchers() async {
    return await getVouchersByStatus(AppConstants.voucherStatusUnused);
  }

  // Get sold vouchers
  Future<List<Voucher>> getSoldVouchers() async {
    return await getVouchersByStatus(AppConstants.voucherStatusSold);
  }

  // Get active vouchers
  Future<List<Voucher>> getActiveVouchers() async {
    return await getVouchersByStatus(AppConstants.voucherStatusActive);
  }

  // Get expired vouchers
  Future<List<Voucher>> getExpiredVouchers() async {
    return await getVouchersByStatus(AppConstants.voucherStatusExpired);
  }

  // Get vouchers by site
  Future<List<Voucher>> getVouchersBySite(int siteId) async {
    return await (_database.select(
      _database.vouchers,
    )..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  // Get vouchers by agent
  Future<List<Voucher>> getVouchersByAgent(int agentId) async {
    return await (_database.select(
      _database.vouchers,
    )..where((tbl) => tbl.agentId.equals(agentId)))
        .get();
  }

  // Sell voucher
  Future<bool> sellVoucher({
    required int voucherId,
    required int? clientId,
  }) async {
    return await (_database.update(
          _database.vouchers,
        )..where((tbl) => tbl.id.equals(voucherId)))
            .write(
          VouchersCompanion(
            status: const Value(AppConstants.voucherStatusSold),
            clientId: Value(clientId),
            soldAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Activate voucher
  Future<bool> activateVoucher(int voucherId) async {
    final voucher = await getVoucherById(voucherId);
    if (voucher == null) return false;

    final expiryDate = DateTime.now().add(Duration(days: voucher.duration));

    return await (_database.update(
          _database.vouchers,
        )..where((tbl) => tbl.id.equals(voucherId)))
            .write(
          VouchersCompanion(
            status: const Value(AppConstants.voucherStatusActive),
            activatedAt: Value(DateTime.now()),
            expiresAt: Value(expiryDate),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Expire voucher
  Future<bool> expireVoucher(int voucherId) async {
    return await (_database.update(
          _database.vouchers,
        )..where((tbl) => tbl.id.equals(voucherId)))
            .write(
          VouchersCompanion(
            status: const Value(AppConstants.voucherStatusExpired),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Update voucher
  Future<bool> updateVoucher(int id, VouchersCompanion voucher) async {
    return await (_database.update(
          _database.vouchers,
        )..where((tbl) => tbl.id.equals(id)))
            .write(
          voucher.copyWith(
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        ) >
        0;
  }

  // Delete voucher
  Future<int> deleteVoucher(int id) async {
    return await (_database.delete(
      _database.vouchers,
    )..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Get voucher counts by status
  Future<Map<String, int>> getVoucherCounts() async {
    final allVouchers = await getAllVouchers();
    return {
      'total': allVouchers.length,
      'unused': allVouchers
          .where((v) => v.status == AppConstants.voucherStatusUnused)
          .length,
      'sold': allVouchers
          .where((v) => v.status == AppConstants.voucherStatusSold)
          .length,
      'active': allVouchers
          .where((v) => v.status == AppConstants.voucherStatusActive)
          .length,
      'expired': allVouchers
          .where((v) => v.status == AppConstants.voucherStatusExpired)
          .length,
    };
  }

  // Get vouchers with pagination
  Future<List<Voucher>> getVouchersPaginated({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    final offset = (page - 1) * pageSize;
    var query = _database.select(_database.vouchers);

    if (status != null) {
      query = query..where((tbl) => tbl.status.equals(status));
    }

    query = query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(pageSize, offset: offset);

    return await query.get();
  }

  // Helper: Generate voucher code
  String _generateVoucherCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      12,
      (index) => chars[(DateTime.now().microsecond + index) % chars.length],
    ).join();
  }

  // Helper: Generate password
  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      8,
      (index) => chars[(DateTime.now().microsecond + index) % chars.length],
    ).join();
  }
}

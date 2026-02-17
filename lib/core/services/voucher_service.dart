import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class VoucherService {
  /// Get ISP subscription info for a client (admin/finance only)
  /// Returns: { 'lastPaid': DateTime?, 'subscriptionEnds': DateTime? }
  /// Only to be shown to admin/finance users in the UI
  Future<Map<String, DateTime?>> getClientSubscriptionInfo(int clientId) async {
    // Get last purchase date and expiry date from Clients table
    final client = await (db.select(db.clients)
          ..where((tbl) => tbl.id.equals(clientId)))
        .getSingleOrNull();
    if (client == null) {
      return {'lastPaid': null, 'subscriptionEnds': null};
    }
    return {
      'lastPaid': client.lastPurchaseDate,
      'subscriptionEnds': client.expiryDate,
    };
  }

  /// Get all clients with their subscription info (admin/finance only)
  /// Returns a list of { 'client': Client, 'lastPaid': DateTime?, 'subscriptionEnds': DateTime? }
  Future<List<Map<String, dynamic>>> getAllClientsSubscriptionInfo() async {
    final clients = await db.select(db.clients).get();
    return clients
        .map((client) => {
              'client': client,
              'lastPaid': client.lastPurchaseDate,
              'subscriptionEnds': client.expiryDate,
            })
        .toList();
  }

  final AppDatabase db;
  final _uuid = const Uuid();

  VoucherService(this.db);

  /// Parse Mikrotik HTML voucher file and extract voucher codes
  Future<List<Map<String, dynamic>>> parseHtmlVouchers(
      String htmlContent) async {
    final vouchers = <Map<String, dynamic>>[];

    // Extract voucher codes using regex pattern
    // Looking for patterns like: <div class="user">645827</div>
    final codePattern = RegExp(r'<div class="user">(\d{6})</div>');
    final codes = codePattern.allMatches(htmlContent);

    // Extract price (e.g., "500 TZS")
    final pricePattern = RegExp(r'<div class="form3"[^>]*>(\d+)\s*TZS</div>');
    final priceMatches = pricePattern.allMatches(htmlContent).toList();

    // Extract validity (e.g., "12Hours")
    final validityPattern = RegExp(r'VALIDITY:\s*([^<]+)</div>');
    final validityMatches = validityPattern.allMatches(htmlContent).toList();

    // Extract speed info
    final speedPattern = RegExp(r'SPEED:\s*([^<]*)</div>');
    final speedMatches = speedPattern.allMatches(htmlContent).toList();

    // Extract QR code data (URL)
    final qrPattern = RegExp(r'"text":\s*"([^"]+)"');
    final qrMatches = qrPattern.allMatches(htmlContent).toList();

    int index = 0;
    for (final match in codes) {
      final code = match.group(1);
      if (code != null && code != '.') {
        // Skip placeholder dots
        double? price;
        if (index < priceMatches.length) {
          final priceStr = priceMatches[index].group(1);
          price = priceStr != null ? double.tryParse(priceStr) : null;
        }

        String? validity;
        if (index < validityMatches.length) {
          validity = validityMatches[index].group(1)?.trim();
        }

        String? speed;
        if (index < speedMatches.length) {
          speed = speedMatches[index].group(1)?.trim();
          if (speed != null && speed.isEmpty) speed = null;
        }

        String? qrCodeData;
        if (index < qrMatches.length) {
          qrCodeData = qrMatches[index].group(1);
        }

        vouchers.add({
          'code': code,
          'price': price,
          'validity': validity,
          'speed': speed,
          'qrCodeData': qrCodeData,
        });

        index++;
      }
    }

    return vouchers;
  }

  /// Bulk insert vouchers from HTML file
  Future<int> bulkInsertVouchers({
    required String htmlContent,
    int? packageId,
    int? siteId,
    String? batchId,
  }) async {
    final parsedVouchers = await parseHtmlVouchers(htmlContent);
    final generatedBatchId = batchId ?? _uuid.v4();

    int insertedCount = 0;

    for (final voucherData in parsedVouchers) {
      try {
        await db.into(db.vouchers).insert(
              VouchersCompanion.insert(
                serverId: Value(_uuid.v4()),
                code: voucherData['code'] as String,
                packageId: Value(packageId),
                siteId: Value(siteId),
                price: Value(voucherData['price'] as double?),
                validity: Value(voucherData['validity'] as String?),
                speed: Value(voucherData['speed'] as String?),
                status: 'AVAILABLE',
                qrCodeData: Value(voucherData['qrCodeData'] as String?),
                batchId: Value(generatedBatchId),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore, // Skip duplicates
            );
        insertedCount++;
      } catch (e) {
        // Skip duplicate codes
        continue;
      }
    }

    return insertedCount;
  }

  /// Add single voucher manually
  Future<int> addVoucher({
    required String code,
    int? packageId,
    int? siteId,
    double? price,
    String? validity,
    String? speed,
    String? qrCodeData,
  }) async {
    return await db.into(db.vouchers).insert(
          VouchersCompanion.insert(
            serverId: Value(_uuid.v4()),
            code: code,
            packageId: Value(packageId),
            siteId: Value(siteId),
            price: Value(price),
            validity: Value(validity),
            speed: Value(speed),
            status: 'AVAILABLE',
            qrCodeData: Value(qrCodeData),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// Get voucher by code
  Future<Voucher?> getVoucherByCode(String code) async {
    return await (db.select(db.vouchers)..where((tbl) => tbl.code.equals(code)))
        .getSingleOrNull();
  }

  /// Get available vouchers (not sold)
  Future<List<Voucher>> getAvailableVouchers({int? packageId}) async {
    final query = db.select(db.vouchers)
      ..where((tbl) => tbl.status.equals('AVAILABLE'));

    if (packageId != null) {
      query.where((tbl) => tbl.packageId.equals(packageId));
    }

    query.orderBy([(tbl) => OrderingTerm.asc(tbl.code)]);

    return await query.get();
  }

  /// Mark voucher as sold
  Future<bool> markVoucherAsSold({
    required int voucherId,
    required int soldByUserId,
  }) async {
    final updated = await (db.update(db.vouchers)
          ..where((tbl) => tbl.id.equals(voucherId)))
        .write(
      VouchersCompanion(
        status: const Value('SOLD'),
        soldAt: Value(DateTime.now()),
        soldByUserId: Value(soldByUserId),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    return updated > 0;
  }

  /// Mark voucher as used (customer activated it)
  Future<bool> markVoucherAsUsed(int voucherId) async {
    final updated = await (db.update(db.vouchers)
          ..where((tbl) => tbl.id.equals(voucherId)))
        .write(
      VouchersCompanion(
        status: const Value('USED'),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    return updated > 0;
  }

  /// Get all vouchers with filters
  Stream<List<Voucher>> watchVouchers({
    String? status,
    int? packageId,
    int? siteId,
    String? batchId,
  }) {
    final query = db.select(db.vouchers);

    if (status != null) {
      query.where((tbl) => tbl.status.equals(status));
    }

    if (packageId != null) {
      query.where((tbl) => tbl.packageId.equals(packageId));
    }

    if (siteId != null) {
      query.where((tbl) => tbl.siteId.equals(siteId));
    }

    if (batchId != null) {
      query.where((tbl) => tbl.batchId.equals(batchId));
    }

    query.orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

    return query.watch();
  }

  /// Get voucher statistics
  Future<Map<String, int>> getVoucherStats() async {
    final total = await (db.select(db.vouchers)).get();
    final available = total.where((v) => v.status == 'AVAILABLE').length;
    final sold = total.where((v) => v.status == 'SOLD').length;
    final used = total.where((v) => v.status == 'USED').length;
    final expired = total.where((v) => v.status == 'EXPIRED').length;

    return {
      'total': total.length,
      'available': available,
      'sold': sold,
      'used': used,
      'expired': expired,
    };
  }

  /// Delete voucher (admin only)
  Future<bool> deleteVoucher(int voucherId) async {
    final deleted = await (db.delete(db.vouchers)
          ..where((tbl) => tbl.id.equals(voucherId)))
        .go();

    return deleted > 0;
  }

  /// Delete batch of vouchers
  Future<int> deleteBatch(String batchId) async {
    return await (db.delete(db.vouchers)
          ..where((tbl) => tbl.batchId.equals(batchId)))
        .go();
  }

  /// Update voucher details
  Future<bool> updateVoucher({
    required int voucherId,
    int? packageId,
    double? price,
    String? validity,
    String? speed,
  }) async {
    final updated = await (db.update(db.vouchers)
          ..where((tbl) => tbl.id.equals(voucherId)))
        .write(
      VouchersCompanion(
        packageId: Value(packageId),
        price: Value(price),
        validity: Value(validity),
        speed: Value(speed),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    return updated > 0;
  }
}

import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import 'supabase_data_service.dart';

class VoucherService {
  final SupabaseDataService _service;
  final _uuid = const Uuid();

  VoucherService(this._service);

  // â”€â”€ HTML Parsing (pure Dart â€“ no DB dependency) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Parse Mikrotik HTML voucher file and extract voucher codes.
  ///
  /// Supports two HTML template formats:
  ///   • Old format: codes in `<div class="user">XXXXXX</div>` (6 digits),
  ///     price in `<div class="form3">NNN TZS</div>`.
  ///   • New format: codes in `<td class="qrcode" id="XXXX">` (any length),
  ///     price/validity/speed in `<span>…PRICE: NNN…</span>` fields.
  Future<List<Map<String, dynamic>>> parseHtmlVouchers(
      String htmlContent) async {
    // ── QR data is the same in both formats ──────────────────────────────
    final qrPattern = RegExp(r'"text":\s*"([^"]+)"');
    final qrMatches = qrPattern.allMatches(htmlContent).toList();

    // ── Detect format ─────────────────────────────────────────────────────
    final oldCodePattern = RegExp(r'<div class="user">(\d+)</div>');
    final oldCodes = oldCodePattern.allMatches(htmlContent).toList();

    if (oldCodes.isNotEmpty) {
      // ── Old format ───────────────────────────────────────────────────────
      final pricePattern =
          RegExp(r'<div class="form3"[^>]*>(\d+(?:\.\d+)?)\s*(?:TZS)?</div>');
      final priceMatches = pricePattern.allMatches(htmlContent).toList();
      final validityPattern = RegExp(r'VALIDITY:\s*([^<]+)<');
      final validityMatches = validityPattern.allMatches(htmlContent).toList();
      final speedPattern = RegExp(r'SPEED:\s*([^<]*)<');
      final speedMatches = speedPattern.allMatches(htmlContent).toList();

      final vouchers = <Map<String, dynamic>>[];
      for (int i = 0; i < oldCodes.length; i++) {
        final code = oldCodes[i].group(1);
        if (code == null || code == '.') continue;
        vouchers.add({
          'code': code,
          'price': i < priceMatches.length
              ? double.tryParse(priceMatches[i].group(1) ?? '')
              : null,
          'validity': i < validityMatches.length
              ? validityMatches[i].group(1)?.trim()
              : null,
          'speed': () {
            if (i >= speedMatches.length) return null;
            final s = speedMatches[i].group(1)?.trim();
            return (s == null || s.isEmpty) ? null : s;
          }(),
          'qrCodeData': i < qrMatches.length ? qrMatches[i].group(1) : null,
        });
      }
      return vouchers;
    }

    // ── New format: <td class="qrcode" id="CODE"> ────────────────────────
    final newCodePattern = RegExp(r'<td[^>]+class="qrcode"[^>]+id="([^"]+)"');
    final newCodes = newCodePattern.allMatches(htmlContent).toList();

    final pricePattern = RegExp(r'PRICE:\s*(\d+(?:\.\d+)?)');
    final priceMatches = pricePattern.allMatches(htmlContent).toList();
    final validityPattern = RegExp(r'VALIDITY:\s*([^<]+)<');
    final validityMatches = validityPattern.allMatches(htmlContent).toList();
    final speedPattern = RegExp(r'SPEED:\s*([^<]+)<');
    final speedMatches = speedPattern.allMatches(htmlContent).toList();

    final vouchers = <Map<String, dynamic>>[];
    for (int i = 0; i < newCodes.length; i++) {
      final code = newCodes[i].group(1);
      if (code == null || code == '.') continue;
      vouchers.add({
        'code': code,
        'price': i < priceMatches.length
            ? double.tryParse(priceMatches[i].group(1) ?? '')
            : null,
        'validity': i < validityMatches.length
            ? validityMatches[i].group(1)?.trim()
            : null,
        'speed': () {
          if (i >= speedMatches.length) return null;
          final s = speedMatches[i].group(1)?.trim();
          return (s == null || s.isEmpty) ? null : s;
        }(),
        'qrCodeData': i < qrMatches.length ? qrMatches[i].group(1) : null,
      });
    }
    return vouchers;
  }

  // â”€â”€ Bulk insert from HTML â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<int> bulkInsertVouchers({
    required String htmlContent,
    int? packageId,
    int? siteId,
    String? batchId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final parsedVouchers = await parseHtmlVouchers(htmlContent);
    final generatedBatchId = batchId ?? _uuid.v4();
    final toInsert = parsedVouchers
        .map((v) => {
              'code': v['code'],
              'package_id': packageId,
              'site_id': siteId,
              'price': v['price'],
              'validity': v['validity'],
              'speed': v['speed'],
              'qr_code_data': v['qrCodeData'],
              'batch_id': generatedBatchId,
              'status': 'AVAILABLE',
            })
        .toList();
    return _service.bulkInsertVouchers(
      toInsert,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  // â”€â”€ Single voucher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<Voucher> addVoucher({
    required String code,
    int? packageId,
    int? siteId,
    double? price,
    String? validity,
    String? speed,
    String? qrCodeData,
    String? batchId,
  }) =>
      _service.createVoucher({
        'code': code,
        'package_id': packageId,
        'site_id': siteId,
        'price': price,
        'validity': validity,
        'speed': speed,
        'qr_code_data': qrCodeData,
        if (batchId != null) 'batch_id': batchId,
      });

  Future<Voucher?> getVoucherByCode(String code) =>
      _service.getVoucherByCode(code);

  Future<List<Voucher>> getAvailableVouchers({int? packageId}) =>
      _service.getAvailableVouchers(packageId: packageId);

  Future<bool> markVoucherAsSold({
    required int voucherId,
    required int soldByUserId,
  }) =>
      _service.markVoucherAsSold(
          voucherId: voucherId, soldByUserId: soldByUserId);

  Future<bool> markVoucherAsUsed(int voucherId) =>
      _service.markVoucherAsUsed(voucherId);

  /// Returns a Future (not a Stream) — screens should poll or use FutureBuilder
  Future<List<Voucher>> watchVouchers({
    String? status,
    int? packageId,
    int? siteId,
    List<int>? siteIds,
    String? batchId,
  }) =>
      _service.getAllVouchers(
          status: status,
          packageId: packageId,
          siteId: siteId,
          siteIds: siteIds,
          batchId: batchId);

  Future<Map<String, int>> getVoucherStats() => _service.getVoucherStats();

  Future<bool> deleteVoucher(int voucherId) =>
      _service.deleteVoucher(voucherId);

  Future<int> deleteBatch(String batchId) => _service.deleteBatch(batchId);

  Future<bool> updateVoucher({
    required int voucherId,
    int? packageId,
    double? price,
    String? validity,
    String? speed,
  }) =>
      _service.updateVoucher(voucherId, {
        if (packageId != null) 'package_id': packageId,
        if (price != null) 'price': price,
        if (validity != null) 'validity': validity,
        if (speed != null) 'speed': speed,
      });

  Future<Map<String, DateTime?>> getClientSubscriptionInfo(int clientId) async {
    final client = await _service.getClientById(clientId);
    return {
      'lastPaid': client?.lastPurchaseDate,
      'subscriptionEnds': client?.expiryDate,
    };
  }

  Future<List<Map<String, dynamic>>> getAllClientsSubscriptionInfo() async {
    final clients = await _service.getAllClients();
    return clients
        .map((c) => {
              'client': c,
              'lastPaid': c.lastPurchaseDate,
              'subscriptionEnds': c.expiryDate,
            })
        .toList();
  }
}

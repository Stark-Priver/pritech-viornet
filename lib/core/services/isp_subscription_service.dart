import 'package:drift/drift.dart';
import '../database/database.dart';

/// Service for tracking the reseller's own ISP subscription (not for clients)
class IspSubscriptionService {
  final AppDatabase db;
  IspSubscriptionService(this.db);

  /// Add a new ISP subscription payment for a site
  Future<int> addIspSubscription({
    required int siteId,
    required String providerName,
    required DateTime paidAt,
    required DateTime endsAt,
    String? paymentControlNumber,
    String? registeredName,
    String? serviceNumber,
    double? amount,
    String? notes,
  }) async {
    return await db.into(db.ispSubscriptions).insert(
          IspSubscriptionsCompanion.insert(
            siteId: siteId,
            providerName: providerName,
            paidAt: paidAt,
            endsAt: endsAt,
            paymentControlNumber: Value(paymentControlNumber),
            registeredName: Value(registeredName),
            serviceNumber: Value(serviceNumber),
            amount: Value(amount),
            notes: Value(notes),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// Update an existing ISP subscription record
  Future<bool> updateIspSubscription({
    required int id,
    int? siteId,
    String? providerName,
    DateTime? paidAt,
    DateTime? endsAt,
    String? paymentControlNumber,
    String? registeredName,
    String? serviceNumber,
    double? amount,
    String? notes,
  }) async {
    final updated = await (db.update(db.ispSubscriptions)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      IspSubscriptionsCompanion(
        siteId: siteId != null ? Value(siteId) : const Value.absent(),
        providerName:
            providerName != null ? Value(providerName) : const Value.absent(),
        paidAt: paidAt != null ? Value(paidAt) : const Value.absent(),
        endsAt: endsAt != null ? Value(endsAt) : const Value.absent(),
        paymentControlNumber: paymentControlNumber != null
            ? Value(paymentControlNumber)
            : const Value.absent(),
        registeredName: registeredName != null
            ? Value(registeredName)
            : const Value.absent(),
        serviceNumber:
            serviceNumber != null ? Value(serviceNumber) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }

  /// Get all ISP subscriptions for a site (history)
  Future<List<IspSubscription>> getIspSubscriptionsForSite(int siteId) async {
    return await (db.select(db.ispSubscriptions)
          ..where((tbl) => tbl.siteId.equals(siteId)))
        .get();
  }

  /// Get the latest ISP subscription for a site
  Future<IspSubscription?> getLatestIspSubscriptionForSite(int siteId) async {
    final query = db.select(db.ispSubscriptions)
      ..where((tbl) => tbl.siteId.equals(siteId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.paidAt),
      ])
      ..limit(1);
    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }

  /// Delete an ISP subscription record
  Future<bool> deleteIspSubscription(int id) async {
    final deleted = await (db.delete(db.ispSubscriptions)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
    return deleted > 0;
  }
}

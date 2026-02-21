import '../models/app_models.dart';
import 'supabase_data_service.dart';

/// Service for tracking the reseller's own ISP subscription (not for clients)
class IspSubscriptionService {
  final SupabaseDataService _service;

  IspSubscriptionService(this._service);

  Future<IspSubscription> addIspSubscription({
    required int siteId,
    required String providerName,
    required DateTime paidAt,
    required DateTime endsAt,
    String? paymentControlNumber,
    String? registeredName,
    String? serviceNumber,
    double? amount,
    String? notes,
  }) =>
      _service.createIspSubscription({
        'site_id': siteId,
        'provider_name': providerName,
        'paid_at': paidAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        if (paymentControlNumber != null)
          'payment_control_number': paymentControlNumber,
        if (registeredName != null) 'registered_name': registeredName,
        if (serviceNumber != null) 'service_number': serviceNumber,
        if (amount != null) 'amount': amount,
        if (notes != null) 'notes': notes,
      });

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
  }) =>
      _service.updateIspSubscription(id, {
        if (siteId != null) 'site_id': siteId,
        if (providerName != null) 'provider_name': providerName,
        if (paidAt != null) 'paid_at': paidAt.toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
        if (paymentControlNumber != null)
          'payment_control_number': paymentControlNumber,
        if (registeredName != null) 'registered_name': registeredName,
        if (serviceNumber != null) 'service_number': serviceNumber,
        if (amount != null) 'amount': amount,
        if (notes != null) 'notes': notes,
      });

  Future<List<IspSubscription>> getIspSubscriptionsForSite(int siteId) =>
      _service.getIspSubscriptionsForSite(siteId);

  Future<IspSubscription?> getLatestIspSubscriptionForSite(int siteId) =>
      _service.getLatestIspSubscriptionForSite(siteId);

  Future<bool> deleteIspSubscription(int id) =>
      _service.deleteIspSubscription(id);
}

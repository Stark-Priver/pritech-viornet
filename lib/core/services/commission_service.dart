import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/app_models.dart';
import 'supabase_data_service.dart';

/// Commission calculation service
class CommissionService {
  final SupabaseDataService _service;

  CommissionService(this._service);

  /// Calculate commission for a sale
  Future<double> calculateCommission({
    required int agentId,
    required double saleAmount,
    required int saleId,
    int? clientId,
    int? packageId,
  }) async {
    try {
      final agent = await _service.getUserById(agentId);
      if (agent == null) return 0.0;

      final roleNames = await _service.getUserRoleNames(agentId);

      final settings = await _service.getActiveCommissionSettings();
      // Settings already sorted by priority descending

      double totalCommission = 0.0;
      CommissionSetting? appliedSetting;
      final calculationDetails = <String, dynamic>{
        'saleAmount': saleAmount,
        'agentId': agentId,
        'agentName': agent.name,
        'clientId': clientId,
        'packageId': packageId,
        'rules': <dynamic>[],
      };

      for (final setting in settings) {
        if (saleAmount < setting.minSaleAmount) {
          continue;
        }
        if (setting.maxSaleAmount != null &&
            saleAmount > setting.maxSaleAmount!) {
          continue;
        }

        bool applicable = false;
        if (setting.applicableTo == 'ALL_AGENTS') {
          applicable = true;
        } else if (setting.applicableTo == 'SPECIFIC_ROLE' &&
            setting.roleId != null &&
            roleNames.isNotEmpty) {
          // Check if agent has the required role
          final allRoles = await _service.getAllRoles();
          final role =
              allRoles.where((r) => r.id == setting.roleId).firstOrNull;
          if (role != null && roleNames.contains(role.name)) applicable = true;
        } else if (setting.applicableTo == 'SPECIFIC_USER' &&
            setting.userId == agentId) {
          applicable = true;
        } else if (setting.applicableTo == 'SPECIFIC_CLIENT' &&
            setting.clientId != null &&
            clientId != null &&
            setting.clientId == clientId) {
          applicable = true;
        } else if (setting.applicableTo == 'SPECIFIC_PACKAGE' &&
            setting.packageId != null &&
            packageId != null &&
            setting.packageId == packageId) {
          applicable = true;
        }

        if (!applicable) continue;

        double commission = 0.0;
        if (setting.commissionType == 'PERCENTAGE') {
          commission = (saleAmount * setting.rate) / 100;
        } else if (setting.commissionType == 'FIXED_AMOUNT') {
          commission = setting.rate;
        }

        totalCommission += commission;
        (calculationDetails['rules'] as List).add({
          'settingId': setting.id,
          'name': setting.name,
          'type': setting.commissionType,
          'rate': setting.rate,
          'commission': commission,
          'applicableTo': setting.applicableTo,
        });
        appliedSetting ??= setting;
      }

      // Record commission history
      await _service.createCommissionHistory({
        'sale_id': saleId,
        'agent_id': agentId,
        'commission_amount': totalCommission,
        'sale_amount': saleAmount,
        if (appliedSetting != null) 'commission_setting_id': appliedSetting.id,
        if (appliedSetting != null) 'commission_rate': appliedSetting.rate,
        'calculation_details': jsonEncode(calculationDetails),
        'status': 'PENDING',
      });

      debugPrint(
          'âœ… Commission calculated: ${totalCommission.toStringAsFixed(2)} for sale ID: $saleId');
      return totalCommission;
    } catch (e) {
      debugPrint('âŒ Commission calculation failed: $e');
      return 0.0;
    }
  }

  /// Get agent's commission summary
  Future<Map<String, dynamic>> getAgentCommissionSummary(
    int agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var history = await _service.getCommissionHistoryByAgent(agentId);

      if (startDate != null) {
        history = history.where((h) => h.createdAt.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        history = history.where((h) => h.createdAt.isBefore(endDate)).toList();
      }

      double totalCommission = 0.0;
      double totalSales = 0.0;
      final commissionByStatus = <String, double>{
        'PENDING': 0.0,
        'APPROVED': 0.0,
        'PAID': 0.0,
        'CANCELLED': 0.0,
      };

      for (final h in history) {
        totalCommission += h.commissionAmount;
        totalSales += h.saleAmount;
        commissionByStatus[h.status] =
            (commissionByStatus[h.status] ?? 0.0) + h.commissionAmount;
      }

      return {
        'totalCommission': totalCommission,
        'totalSales': totalSales,
        'salesCount': history.length,
        'averageCommission':
            history.isNotEmpty ? totalCommission / history.length : 0.0,
        'averageSale': history.isNotEmpty ? totalSales / history.length : 0.0,
        'commissionByStatus': commissionByStatus,
        'commissionRate':
            totalSales > 0 ? (totalCommission / totalSales) * 100 : 0.0,
      };
    } catch (e) {
      debugPrint('âŒ Failed to get commission summary: $e');
      return {};
    }
  }

  Future<List<CommissionHistory>> getAgentCommissions(
    int agentId, {
    String? status,
    int limit = 50,
  }) async {
    var history = await _service.getCommissionHistoryByAgent(agentId);
    if (status != null) {
      history = history.where((h) => h.status == status).toList();
    }
    return history.take(limit).toList();
  }

  Future<bool> approveCommission(int commissionId, int approvedBy) async {
    try {
      await _service.updateCommissionHistory(commissionId, {
        'status': 'APPROVED',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('âŒ Failed to approve commission: $e');
      return false;
    }
  }

  Future<bool> markCommissionPaid(int commissionId) async {
    try {
      await _service.updateCommissionHistory(commissionId, {
        'status': 'PAID',
        'paid_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('âŒ Failed to mark commission as paid: $e');
      return false;
    }
  }

  Future<List<CommissionHistory>> getPendingCommissions() async {
    // Get commission_history with status=PENDING for all agents
    final data = await _service.getCommissionHistoryByAgent(0);
    return data.where((h) => h.status == 'PENDING').toList();
  }
}

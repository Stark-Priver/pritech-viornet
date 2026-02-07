import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import 'dart:convert';

/// Commission calculation service
/// Handles automatic commission calculation, tracking, and reporting
class CommissionService {
  final AppDatabase _database;

  CommissionService(this._database);

  /// Calculate commission for a sale
  /// Returns the commission amount based on active rules
  Future<double> calculateCommission({
    required int agentId,
    required double saleAmount,
    required int saleId,
    int? clientId,
    int? packageId,
  }) async {
    try {
      // Get agent details including roles
      final agent = await (_database.select(_database.users)
            ..where((tbl) => tbl.id.equals(agentId)))
          .getSingle();

      final agentRoles = await (_database.select(_database.userRoles).join([
        innerJoin(_database.roles,
            _database.roles.id.equalsExp(_database.userRoles.roleId)),
      ])
            ..where(_database.userRoles.userId.equals(agentId)))
          .get();

      final roleIds =
          agentRoles.map((row) => row.readTable(_database.roles).id).toList();

      // Get applicable commission settings (sorted by priority)
      final settings = await (_database.select(_database.commissionSettings)
            ..where((tbl) =>
                tbl.isActive.equals(true) &
                tbl.minSaleAmount.isSmallerOrEqualValue(saleAmount) &
                (tbl.maxSaleAmount.isNull() |
                    tbl.maxSaleAmount.isBiggerOrEqualValue(saleAmount)))
            ..orderBy([
              (tbl) => OrderingTerm.desc(tbl.priority),
              (tbl) => OrderingTerm.asc(tbl.id),
            ]))
          .get();

      double totalCommission = 0.0;
      CommissionSetting? appliedSetting;
      Map<String, dynamic> calculationDetails = {
        'saleAmount': saleAmount,
        'agentId': agentId,
        'agentName': agent.name,
        'clientId': clientId,
        'packageId': packageId,
        'rules': [],
      };

      for (final setting in settings) {
        bool applicable = false;

        // Check if rule applies to this agent/client/package
        if (setting.applicableTo == 'ALL_AGENTS') {
          applicable = true;
        } else if (setting.applicableTo == 'SPECIFIC_ROLE' &&
            setting.roleId != null &&
            roleIds.contains(setting.roleId)) {
          applicable = true;
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

        // Calculate commission based on type
        double commission = 0.0;
        if (setting.commissionType == 'PERCENTAGE') {
          commission = (saleAmount * setting.rate) / 100;
        } else if (setting.commissionType == 'FIXED_AMOUNT') {
          commission = setting.rate;
        }

        totalCommission += commission;
        calculationDetails['rules'].add({
          'settingId': setting.id,
          'name': setting.name,
          'type': setting.commissionType,
          'rate': setting.rate,
          'commission': commission,
          'applicableTo': setting.applicableTo,
        });

        appliedSetting ??= setting; // Use first applied setting for record
      }

      // Create commission history record
      await _database.into(_database.commissionHistory).insert(
            CommissionHistoryCompanion.insert(
              saleId: saleId,
              agentId: agentId,
              commissionAmount: totalCommission,
              saleAmount: saleAmount,
              commissionSettingId: appliedSetting != null
                  ? Value(appliedSetting.id)
                  : const Value.absent(),
              commissionRate: appliedSetting != null
                  ? Value(appliedSetting.rate)
                  : const Value.absent(),
              calculationDetails: Value(jsonEncode(calculationDetails)),
              status: const Value('PENDING'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      debugPrint(
          '✅ Commission calculated: ${totalCommission.toStringAsFixed(2)} for sale ID: $saleId');

      return totalCommission;
    } catch (e) {
      debugPrint('❌ Commission calculation failed: $e');
      return 0.0;
    }
  }

  /// Get agent's commission summary
  Future<Map<String, dynamic>> getAgentCommissionSummary(int agentId,
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _database.select(_database.commissionHistory).join([
        innerJoin(_database.sales,
            _database.sales.id.equalsExp(_database.commissionHistory.saleId)),
      ])
        ..where(_database.commissionHistory.agentId.equals(agentId));

      if (startDate != null) {
        query = query
          ..where(_database.sales.saleDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(_database.sales.saleDate.isSmallerOrEqualValue(endDate));
      }

      final results = await query.get();

      double totalCommission = 0.0;
      double totalSales = 0.0;
      int salesCount = 0;
      Map<String, double> commissionByStatus = {
        'PENDING': 0.0,
        'APPROVED': 0.0,
        'PAID': 0.0,
        'CANCELLED': 0.0,
      };

      for (final row in results) {
        final commission = row.readTable(_database.commissionHistory);
        totalCommission += commission.commissionAmount;
        totalSales += commission.saleAmount;
        salesCount++;
        commissionByStatus[commission.status] =
            (commissionByStatus[commission.status] ?? 0.0) +
                commission.commissionAmount;
      }

      return {
        'totalCommission': totalCommission,
        'totalSales': totalSales,
        'salesCount': salesCount,
        'averageCommission':
            salesCount > 0 ? totalCommission / salesCount : 0.0,
        'averageSale': salesCount > 0 ? totalSales / salesCount : 0.0,
        'commissionByStatus': commissionByStatus,
        'commissionRate': totalSales > 0
            ? (totalCommission / totalSales) * 100
            : 0.0, // Effective rate
      };
    } catch (e) {
      debugPrint('❌ Failed to get commission summary: $e');
      return {};
    }
  }

  /// Get commission history for agent
  Future<List<CommissionHistoryData>> getAgentCommissions(
    int agentId, {
    String? status,
    int limit = 50,
  }) async {
    var query = _database.select(_database.commissionHistory).join([
      innerJoin(_database.sales,
          _database.sales.id.equalsExp(_database.commissionHistory.saleId)),
    ])
      ..where(_database.commissionHistory.agentId.equals(agentId))
      ..orderBy([OrderingTerm.desc(_database.sales.saleDate)]);

    if (status != null) {
      query = query..where(_database.commissionHistory.status.equals(status));
    }

    query = query..limit(limit);

    final results = await query.get();
    return results
        .map((row) => row.readTable(_database.commissionHistory))
        .toList();
  }

  /// Approve commission (Finance/Admin only)
  Future<bool> approveCommission(int commissionId, int approvedBy) async {
    try {
      await (_database.update(_database.commissionHistory)
            ..where((tbl) => tbl.id.equals(commissionId)))
          .write(CommissionHistoryCompanion(
        status: const Value('APPROVED'),
        approvedBy: Value(approvedBy),
        approvedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));
      return true;
    } catch (e) {
      debugPrint('❌ Failed to approve commission: $e');
      return false;
    }
  }

  /// Mark commission as paid (Finance only)
  Future<bool> markCommissionPaid(int commissionId) async {
    try {
      await (_database.update(_database.commissionHistory)
            ..where((tbl) => tbl.id.equals(commissionId)))
          .write(CommissionHistoryCompanion(
        status: const Value('PAID'),
        paidAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));
      return true;
    } catch (e) {
      debugPrint('❌ Failed to mark commission as paid: $e');
      return false;
    }
  }

  /// Get all pending commissions (for Finance approval)
  Future<List<Map<String, dynamic>>> getPendingCommissions() async {
    final results = await (_database.select(_database.commissionHistory).join([
      innerJoin(_database.users,
          _database.users.id.equalsExp(_database.commissionHistory.agentId)),
      innerJoin(_database.sales,
          _database.sales.id.equalsExp(_database.commissionHistory.saleId)),
    ])
          ..where(_database.commissionHistory.status.equals('PENDING'))
          ..orderBy([OrderingTerm.desc(_database.commissionHistory.createdAt)]))
        .get();

    return results.map((row) {
      final commission = row.readTable(_database.commissionHistory);
      final agent = row.readTable(_database.users);
      final sale = row.readTable(_database.sales);
      return {
        'commission': commission,
        'agent': agent,
        'sale': sale,
      };
    }).toList();
  }
}

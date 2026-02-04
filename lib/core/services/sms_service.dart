import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../constants/app_constants.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;
  final AppDatabase _database = AppDatabase();
  final Logger _logger = Logger();

  // Request SMS permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  // Check if SMS permissions are granted
  Future<bool> hasPermissions() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  // Send single SMS
  Future<bool> sendSms({
    required String phone,
    required String message,
    String type = 'NOTIFICATION',
    int? clientId,
  }) async {
    try {
      final hasPermission = await hasPermissions();
      if (!hasPermission) {
        _logger.w('SMS permission not granted');
        return false;
      }

      // Create SMS log entry
      final smsLog = await _database.into(_database.smsLogs).insert(
            SmsLogsCompanion.insert(
              recipient: phone,
              message: message,
              status: AppConstants.smsStatusPending,
              type: type,
              clientId: clientId != null
                  ? drift.Value(clientId)
                  : const drift.Value.absent(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Send SMS
      await _telephony.sendSms(
        to: phone,
        message: message,
        statusListener: (status) {
          _updateSmsLogStatus(smsLog, status);
        },
      );

      return true;
    } catch (e) {
      _logger.e('Error sending SMS', error: e);
      return false;
    }
  }

  // Send bulk SMS
  Future<void> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String type = 'MARKETING',
  }) async {
    try {
      final hasPermission = await hasPermissions();
      if (!hasPermission) {
        _logger.w('SMS permission not granted');
        return;
      }

      for (final phone in phoneNumbers) {
        await sendSms(phone: phone, message: message, type: type);

        // Small delay between messages
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      _logger.e('Error sending bulk SMS', error: e);
    }
  }

  // Send expiry reminders
  Future<void> sendExpiryReminders() async {
    try {
      // Get clients expiring in next 3 days
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));

      final expiringClients = await (_database.select(_database.clients)
            ..where(
              (tbl) =>
                  tbl.expiryDate.isSmallerOrEqualValue(threeDaysFromNow) &
                  tbl.expiryDate.isBiggerOrEqualValue(now) &
                  tbl.smsReminder.equals(true) &
                  tbl.isActive.equals(true),
            ))
          .get();

      // Get reminder template
      final templates = await (_database.select(_database.smsTemplates)
            ..where(
              (tbl) => tbl.type.equals('REMINDER') & tbl.isActive.equals(true),
            ))
          .get();

      if (templates.isEmpty) {
        _logger.w('No SMS reminder template found');
        return;
      }

      final template = templates.first;

      for (final client in expiringClients) {
        final message = template.message
            .replaceAll('{name}', client.name)
            .replaceAll('{date}', _formatDate(client.expiryDate!));

        await sendSms(
          phone: client.phone,
          message: message,
          type: 'REMINDER',
          clientId: client.id,
        );
      }

      _logger.i('Sent ${expiringClients.length} expiry reminders');
    } catch (e) {
      _logger.e('Error sending expiry reminders', error: e);
    }
  }

  // Send welcome SMS to new client
  Future<void> sendWelcomeSms({
    required String phone,
    required String clientName,
    required String voucherCode,
    int? clientId,
  }) async {
    try {
      // Get welcome template
      final templates = await (_database.select(_database.smsTemplates)
            ..where(
              (tbl) => tbl.type.equals('WELCOME') & tbl.isActive.equals(true),
            ))
          .get();

      if (templates.isEmpty) {
        _logger.w('No welcome SMS template found');
        return;
      }

      final template = templates.first;
      final message = template.message
          .replaceAll('{name}', clientName)
          .replaceAll('{code}', voucherCode)
          .replaceAll(
            '{support_phone}',
            '+255000000000',
          ); // Should be from settings

      await sendSms(
        phone: phone,
        message: message,
        type: 'WELCOME',
        clientId: clientId,
      );
    } catch (e) {
      _logger.e('Error sending welcome SMS', error: e);
    }
  }

  // Update SMS log status
  Future<void> _updateSmsLogStatus(int smsLogId, SendStatus status) async {
    try {
      String smsStatus;
      switch (status) {
        case SendStatus.SENT:
          smsStatus = AppConstants.smsStatusSent;
          break;
        case SendStatus.DELIVERED:
          smsStatus = AppConstants.smsStatusSent;
          break;
      }

      await (_database.update(
        _database.smsLogs,
      )..where((tbl) => tbl.id.equals(smsLogId)))
          .write(
        SmsLogsCompanion(
          status: drift.Value(smsStatus),
          sentAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    } catch (e) {
      _logger.e('Error updating SMS log status', error: e);
    }
  }

  // Get SMS logs
  Future<List<SmsLog>> getSmsLogs({
    String? status,
    String? type,
    int? clientId,
    int limit = 100,
  }) async {
    var query = _database.select(_database.smsLogs);

    if (status != null) {
      query = query..where((tbl) => tbl.status.equals(status));
    }
    if (type != null) {
      query = query..where((tbl) => tbl.type.equals(type));
    }
    if (clientId != null) {
      query = query..where((tbl) => tbl.clientId.equals(clientId));
    }

    query = query
      ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
      ..limit(limit);

    return await query.get();
  }

  // Get pending SMS count
  Future<int> getPendingSmsCount() async {
    final query = _database.select(_database.smsLogs)
      ..where((tbl) => tbl.status.equals(AppConstants.smsStatusPending));

    return await query.get().then((list) => list.length);
  }

  // Retry failed SMS
  Future<void> retryFailedSms() async {
    try {
      final failedSms = await (_database.select(
        _database.smsLogs,
      )..where((tbl) => tbl.status.equals(AppConstants.smsStatusFailed)))
          .get();

      for (final sms in failedSms) {
        await sendSms(
          phone: sms.recipient,
          message: sms.message,
          type: sms.type,
          clientId: sms.clientId,
        );
      }
    } catch (e) {
      _logger.e('Error retrying failed SMS', error: e);
    }
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// SmsService  send SMS from this Android device (native SIM) OR via
// QuickSMS HTTP API. Mirrors the flow from sms_getway-1.1.0.
//
// Channel is stored in SharedPreferences under [AppConstants.smsChannelPrefKey]:
//   'thisPhone'  native Android SIM via MethodChannel (no internet needed)
//   'quickSMS'   HTTP request to QuickSMS REST API

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/app_models.dart';
import 'supabase_data_service.dart';

class SmsService {
  //  Singleton
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  //  Platform channel (same ID as sms_getway-1.1.0)
  static const _platform = MethodChannel(AppConstants.smsPlatformChannel);

  final SupabaseDataService _svc = SupabaseDataService();
  final Logger _logger = Logger();

  // =========================================================================
  // CHANNEL SELECTION
  // =========================================================================

  /// Returns currently selected channel ('thisPhone' or 'quickSMS').
  static Future<String> getSelectedChannel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.smsChannelPrefKey) ??
          AppConstants.smsChannelNative;
    } catch (e) {
      return AppConstants.smsChannelNative;
    }
  }

  /// Persist channel choice.
  static Future<void> setSelectedChannel(String channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.smsChannelPrefKey, channel);
    debugPrint(' SMS channel set to: $channel');
  }

  // =========================================================================
  // PHONE UTILITIES
  // =========================================================================

  /// Format a phone number to E.164 (+255) Tanzania format.
  static String formatPhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');

    // 07xxxxxxxx or 06xxxxxxxx  +255
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = '${AppConstants.defaultCountryCode}${cleaned.substring(1)}';
    }

    // If no leading + add country code
    if (!cleaned.startsWith('+')) {
      cleaned = '${AppConstants.defaultCountryCode}$cleaned';
    }

    return cleaned;
  }

  /// Validate phone number (Tanzania +255 9 digits, or generic E.164).
  static bool validatePhoneNumber(String phone) {
    final formatted = formatPhoneNumber(phone);
    return RegExp(r'^\+255\d{9}$').hasMatch(formatted) ||
        RegExp(r'^\+\d{10,15}$').hasMatch(formatted);
  }

  /// Split a message that exceeds 160 characters.
  static List<String> splitMessage(String message) {
    if (message.length <= 160) return [message];
    return [
      for (int i = 0; i < message.length; i += 160)
        message.substring(i, (i + 160).clamp(0, message.length))
    ];
  }

  // =========================================================================
  // NATIVE ANDROID (thisPhone channel)
  // =========================================================================

  /// Send a single SMS via the device's SIM card.
  static Future<bool> _sendViaNativeAndroid({
    required String phoneNumber,
    required String message,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('  Native SMS is Android-only');
      return false;
    }
    try {
      debugPrint(' Native Android SMS  $phoneNumber');
      final result = await _platform.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      if (result == true) {
        debugPrint(' Native SMS sent  $phoneNumber');
        return true;
      }
      debugPrint(' Native SMS failed  $phoneNumber');
      return false;
    } on PlatformException catch (e) {
      debugPrint(' Platform error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint(' sendViaNativeAndroid error: $e');
      return false;
    }
  }

  /// Send bulk SMS via native Android bulk method channel.
  static Future<Map<String, dynamic>> _sendBulkViaNativeAndroid({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('  Native Bulk SMS is Android-only');
      return {
        'successCount': 0,
        'failedNumbers': phoneNumbers,
        'totalRequested': phoneNumbers.length,
      };
    }
    try {
      final result =
          await _platform.invokeMethod<Map<dynamic, dynamic>>('sendBulkSms', {
        'phoneNumbers': phoneNumbers,
        'message': message,
      });
      if (result != null) {
        return {
          'successCount': result['successCount'] as int? ?? 0,
          'failedNumbers':
              List<String>.from(result['failedNumbers'] as List? ?? []),
          'totalRequested': phoneNumbers.length,
        };
      }
    } on PlatformException catch (e) {
      debugPrint(' Bulk native SMS platform error: ${e.message}');
    } catch (e) {
      debugPrint(' _sendBulkViaNativeAndroid error: $e');
    }
    return {
      'successCount': 0,
      'failedNumbers': phoneNumbers,
      'totalRequested': phoneNumbers.length,
    };
  }

  // =========================================================================
  // QUICKSMS HTTP API (quickSMS channel)
  // =========================================================================

  /// Send a single SMS via QuickSMS REST API.
  static Future<bool> _sendViaQuickSms({
    required String phoneNumber,
    required String message,
  }) async {
    if (AppConstants.quickSmsApiKey.isEmpty) {
      debugPrint('  QuickSMS API key not configured');
      return false;
    }
    try {
      debugPrint(' QuickSMS  $phoneNumber');
      final response = await http
          .post(
            Uri.parse('${AppConstants.quickSmsBaseUrl}/sms/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConstants.quickSmsApiKey}',
            },
            body: jsonEncode({
              'to': phoneNumber,
              'body': message,
              'sender_id': AppConstants.quickSmsSenderId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(' QuickSMS status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(' QuickSMS sent  $phoneNumber');
        return true;
      } else {
        final body = jsonDecode(response.body);
        debugPrint(
            ' QuickSMS error: ${body['message'] ?? response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint(' _sendViaQuickSms error: $e');
      return false;
    }
  }

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Send a single SMS using the currently configured channel.
  /// Logs every attempt (pending  sent/failed) to Supabase sms_logs.
  Future<bool> sendSms({
    required String phone,
    required String message,
    String type = 'NOTIFICATION',
    int? clientId,
    int? sentByUserId,
  }) async {
    final formatted = formatPhoneNumber(phone);

    // Create pending log entry first
    SmsLog? logEntry;
    try {
      logEntry = await _svc.createSmsLog({
        'recipient': formatted,
        'message': message,
        'status': AppConstants.smsStatusPending,
        'type': type,
        if (clientId != null) 'client_id': clientId,
        if (sentByUserId != null) 'sent_by': sentByUserId,
      });
    } catch (e) {
      _logger.w('Could not create SMS log entry: $e');
    }

    // Route to selected channel
    final channel = await getSelectedChannel();
    final bool success;

    if (channel == AppConstants.smsChannelQuickSms) {
      success = await _sendViaQuickSms(
        phoneNumber: formatted,
        message: message,
      );
    } else {
      success = await _sendViaNativeAndroid(
        phoneNumber: formatted,
        message: message,
      );
    }

    // Update log status
    if (logEntry != null) {
      try {
        await _svc.updateSmsLog(logEntry.id, {
          'status': success
              ? AppConstants.smsStatusSent
              : AppConstants.smsStatusFailed,
          'sent_at': success ? DateTime.now().toIso8601String() : null,
          'channel': channel,
        });
      } catch (e) {
        _logger.w('Could not update SMS log: $e');
      }
    }

    return success;
  }

  /// Send SMS to all [phoneNumbers]. Returns counts of success/failures.
  Future<Map<String, dynamic>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String type = 'MARKETING',
    int? sentByUserId,
  }) async {
    final channel = await getSelectedChannel();
    debugPrint(' Bulk SMS via $channel to ${phoneNumbers.length} recipients');

    int successCount = 0;
    final List<String> failedNumbers = [];

    if (channel == AppConstants.smsChannelNative) {
      final formatted = phoneNumbers.map(formatPhoneNumber).toList();

      final result = await _sendBulkViaNativeAndroid(
        phoneNumbers: formatted,
        message: message,
      );
      successCount = result['successCount'] as int;
      failedNumbers.addAll(result['failedNumbers'] as List<String>);

      // Log each
      for (final phone in phoneNumbers) {
        final formatted2 = formatPhoneNumber(phone);
        final ok = !failedNumbers.contains(formatted2);
        await _logBulkEntry(
          phone: phone,
          message: message,
          type: type,
          success: ok,
          channel: channel,
          sentByUserId: sentByUserId,
        );
      }
    } else {
      // QuickSMS: individual sends with delay
      for (final phone in phoneNumbers) {
        final success = await sendSms(
          phone: phone,
          message: message,
          type: type,
          sentByUserId: sentByUserId,
        );
        if (success) {
          successCount++;
        } else {
          failedNumbers.add(phone);
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    debugPrint(
        ' Bulk complete  sent: $successCount, failed: ${failedNumbers.length}');

    return {
      'total': phoneNumbers.length,
      'success': successCount,
      'failed': failedNumbers.length,
      'failedNumbers': failedNumbers,
    };
  }

  Future<void> _logBulkEntry({
    required String phone,
    required String message,
    required String type,
    required bool success,
    required String channel,
    int? sentByUserId,
  }) async {
    try {
      await _svc.createSmsLog({
        'recipient': formatPhoneNumber(phone),
        'message': message,
        'status':
            success ? AppConstants.smsStatusSent : AppConstants.smsStatusFailed,
        'type': type,
        'channel': channel,
        if (sentByUserId != null) 'sent_by': sentByUserId,
        if (success) 'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // =========================================================================
  // TEMPLATE-DRIVEN SENDS
  // =========================================================================

  /// Send expiry reminders to clients expiring within [days] days.
  Future<void> sendExpiryReminders({int days = 3}) async {
    try {
      final expiringClients = await _svc.getExpiringClients(days);
      final templates = await _svc.getAllSmsTemplates();
      final template = templates
          .where((t) => t.type == 'REMINDER' && t.isActive)
          .firstOrNull;

      if (template == null) {
        _logger.w('No active REMINDER SMS template found');
        return;
      }

      int sent = 0;
      for (final client in expiringClients) {
        if (client.smsReminder != true) continue;

        final msg = template.message
            .replaceAll('{name}', client.name)
            .replaceAll(
                '{date}',
                client.expiryDate != null
                    ? _formatDate(client.expiryDate!)
                    : 'N/A');

        final ok = await sendSms(
          phone: client.phone,
          message: msg,
          type: 'REMINDER',
          clientId: client.id,
        );
        if (ok) sent++;
      }

      _logger.i(
          'Expiry reminders: $sent sent of ${expiringClients.length} expiring');
    } catch (e) {
      _logger.e('sendExpiryReminders error', error: e);
    }
  }

  /// Send a welcome SMS to a newly activated client.
  Future<void> sendWelcomeSms({
    required String phone,
    required String clientName,
    required String voucherCode,
    int? clientId,
    String supportPhone = '',
    int? sentByUserId,
  }) async {
    try {
      final templates = await _svc.getAllSmsTemplates();
      final template =
          templates.where((t) => t.type == 'WELCOME' && t.isActive).firstOrNull;

      if (template == null) {
        _logger.w('No active WELCOME SMS template found');
        return;
      }

      final msg = template.message
          .replaceAll('{name}', clientName)
          .replaceAll('{code}', voucherCode)
          .replaceAll('{support_phone}', supportPhone);

      await sendSms(
        phone: phone,
        message: msg,
        type: 'WELCOME',
        clientId: clientId,
        sentByUserId: sentByUserId,
      );
    } catch (e) {
      _logger.e('sendWelcomeSms error', error: e);
    }
  }

  // =========================================================================
  // LOGS & STATS
  // =========================================================================

  Future<List<SmsLog>> getSmsLogs({
    String? status,
    String? type,
    int? clientId,
    int limit = 100,
  }) async {
    var logs = await _svc.getAllSmsLogs();
    if (status != null) logs = logs.where((l) => l.status == status).toList();
    if (type != null) logs = logs.where((l) => l.type == type).toList();
    if (clientId != null) {
      logs = logs.where((l) => l.clientId == clientId).toList();
    }
    return logs.take(limit).toList();
  }

  Future<int> getPendingSmsCount() async {
    final logs = await getSmsLogs(status: AppConstants.smsStatusPending);
    return logs.length;
  }

  /// Re-attempt every failed SMS log entry.
  Future<void> retryFailedSms() async {
    try {
      final failed = await getSmsLogs(status: AppConstants.smsStatusFailed);
      _logger.i('Retrying ${failed.length} failed SMS entries');
      for (final sms in failed) {
        await sendSms(
          phone: sms.recipient,
          message: sms.message,
          type: sms.type,
          clientId: sms.clientId,
        );
      }
    } catch (e) {
      _logger.e('retryFailedSms error', error: e);
    }
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

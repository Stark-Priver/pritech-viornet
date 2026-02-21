// SmsManagerService  SIM card detection and per-SIM SMS dispatch.
// Uses the same MethodChannel as SmsService (com.lwenatech.sms_gateway/sms).
// The Android handler in MainActivity.kt implements sendSms, sendBulkSms, getSimCards.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_constants.dart';
import 'sms_service.dart';

class SimCard {
  final int slotId;
  final int subscriptionId;
  final String displayName;
  final String carrierName;
  final String countryIso;
  final String phoneNumber;

  const SimCard({
    required this.slotId,
    required this.subscriptionId,
    required this.displayName,
    this.carrierName = '',
    this.countryIso = '',
    this.phoneNumber = '',
  });

  factory SimCard.fromMap(Map<dynamic, dynamic> m) => SimCard(
        slotId: m['slotId'] as int? ?? 0,
        subscriptionId: m['subscriptionId'] as int? ?? -1,
        displayName: m['displayName'] as String? ?? 'SIM 1',
        carrierName: m['carrierName'] as String? ?? '',
        countryIso: m['countryIso'] as String? ?? '',
        phoneNumber: m['phoneNumber'] as String? ?? '',
      );

  @override
  String toString() =>
      displayName.isNotEmpty ? displayName : 'SIM ${slotId + 1}';
}

class SmsManagerService {
  //  Singleton
  static final SmsManagerService _instance = SmsManagerService._internal();
  factory SmsManagerService() => _instance;
  SmsManagerService._internal();

  static const _platform = MethodChannel(AppConstants.smsPlatformChannel);
  final Logger _logger = Logger();

  List<SimCard> _simCards = [];
  List<SimCard> get simCards => List.unmodifiable(_simCards);

  // =========================================================================
  // PERMISSIONS
  // =========================================================================

  Future<bool> requestSmsPermissions() async {
    try {
      final results = await [Permission.sms, Permission.phone].request();
      final allGranted = results.values.every((s) => s.isGranted);
      if (!allGranted) _logger.w('Some SMS permissions denied');
      return allGranted;
    } catch (e) {
      _logger.e('requestSmsPermissions error', error: e);
      return false;
    }
  }

  Future<bool> hasSmsPermissions() async {
    return (await Permission.sms.status).isGranted &&
        (await Permission.phone.status).isGranted;
  }

  /// Asks Android to check SEND_SMS permission via platform channel.
  Future<bool> checkPlatformSmsPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _platform.invokeMethod<bool>('checkSmsPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.w('checkPlatformSmsPermission: ${e.message}');
      return false;
    }
  }

  // =========================================================================
  // SIM CARDS
  // =========================================================================

  /// Fetch available SIM cards from Android via the platform channel.
  Future<List<SimCard>> getAvailableSimCards() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _logger.w('SIM card detection is Android-only');
      return [];
    }
    try {
      if (!await hasSmsPermissions()) {
        _logger.w('SMS permissions not granted  cannot detect SIM cards');
        return [];
      }

      final result = await _platform.invokeMethod<List<dynamic>>('getSimCards');

      _simCards = (result ?? [])
          .cast<Map<dynamic, dynamic>>()
          .map((m) => SimCard.fromMap(m))
          .toList();

      _logger.i('Detected ${_simCards.length} SIM card(s)');
      return _simCards;
    } on PlatformException catch (e) {
      _logger.e('getSimCards platform error: ${e.message}');
      // Fallback: return a single SIM placeholder
      _simCards = [
        const SimCard(slotId: 0, subscriptionId: -1, displayName: 'SIM 1')
      ];
      return _simCards;
    } catch (e) {
      _logger.e('getAvailableSimCards error', error: e);
      return [];
    }
  }

  // =========================================================================
  // SEND  (routes through SmsService which handles logging)
  // =========================================================================

  /// Send SMS using the default SIM (delegates to SmsService).
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    SimCard? simCard,
    int? clientId,
    int? sentByUserId,
  }) async {
    if (!await hasSmsPermissions()) {
      _logger.e('SMS permissions not granted');
      return false;
    }

    _logger.i(
        'Sending SMS  $phoneNumber via ${simCard?.displayName ?? 'default SIM'}');

    return SmsService().sendSms(
      phone: phoneNumber,
      message: message,
      clientId: clientId,
      sentByUserId: sentByUserId,
    );
  }

  /// Send bulk SMS to multiple recipients.
  Future<Map<String, dynamic>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    SimCard? simCard,
    String type = 'MARKETING',
    int? sentByUserId,
  }) async {
    if (!await hasSmsPermissions()) {
      _logger.e('SMS permissions not granted');
      return {
        'total': phoneNumbers.length,
        'success': 0,
        'failed': phoneNumbers.length,
        'failedNumbers': phoneNumbers,
      };
    }

    return SmsService().sendBulkSms(
      phoneNumbers: phoneNumbers,
      message: message,
      type: type,
      sentByUserId: sentByUserId,
    );
  }

  // =========================================================================
  // PHONE UTILITIES  (re-exported for convenience)
  // =========================================================================

  static String formatPhoneNumber(String phone) =>
      SmsService.formatPhoneNumber(phone);

  static bool validatePhoneNumber(String phone) =>
      SmsService.validatePhoneNumber(phone);
}

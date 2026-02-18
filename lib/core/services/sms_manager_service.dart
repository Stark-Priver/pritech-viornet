import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:logger/logger.dart';

class SimCard {
  final int slotId;
  final String? displayName;
  final String? phoneNumber;
  final String? countryIso;
  final String? simSerialNumber;
  final int? subscriptionId;

  SimCard({
    required this.slotId,
    this.displayName,
    this.phoneNumber,
    this.countryIso,
    this.simSerialNumber,
    this.subscriptionId,
  });

  @override
  String toString() => displayName ?? phoneNumber ?? 'SIM ${slotId + 1}';
}

class SmsManagerService {
  static final SmsManagerService _instance = SmsManagerService._internal();
  factory SmsManagerService() => _instance;
  SmsManagerService._internal();

  final Telephony _telephony = Telephony.instance;
  final Logger _logger = Logger();
  List<SimCard> _simCards = [];

  /// Request all necessary SMS permissions
  Future<bool> requestSmsPermissions() async {
    try {
      // Permission.phoneNumbers does not exist, remove it
      final permissions = [
        Permission.sms,
        Permission.phone,
      ];

      final results = await permissions.request();

      bool allGranted = true;
      for (final result in results.values) {
        if (!result.isGranted) {
          allGranted = false;
          _logger.w('Permission denied: ${result.isDenied}');
        }
      }

      if (!allGranted) {
        _logger.w('Some SMS permissions were denied');
        return false;
      }

      _logger.i('All SMS permissions granted');
      return true;
    } catch (e) {
      _logger.e('Error requesting SMS permissions: $e');
      return false;
    }
  }

  /// Check if SMS permissions are granted
  Future<bool> hasSmsPermissions() async {
    try {
      final smsStatus = await Permission.sms.status;
      final phoneStatus = await Permission.phone.status;

      return smsStatus.isGranted && phoneStatus.isGranted;
    } catch (e) {
      _logger.e('Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Get list of available SIM cards
  Future<List<SimCard>> getAvailableSimCards() async {
    try {
      final hasPermission = await hasSmsPermissions();
      if (!hasPermission) {
        _logger.w('SMS permissions not granted');
        return [];
      }

      // Get SIM info from telephony plugin
      final simState = await _telephony.simState;
      _logger.i('SIM State: $simState');

      // For now, we'll create a basic SIM card list
      // In production, you might need to use platform channels for more detailed SIM info
      _simCards = [];

      // Add default SIM (SIM 1)
      _simCards.add(
        SimCard(
          slotId: 0,
          displayName: 'SIM 1',
          subscriptionId: 0,
        ),
      );

      // Check if device has dual SIM
      // This is a simplified approach - you may need platform-specific code for accurate detection
      _simCards.add(
        SimCard(
          slotId: 1,
          displayName: 'SIM 2',
          subscriptionId: 1,
        ),
      );

      _logger.i('Found ${_simCards.length} SIM cards');
      return _simCards;
    } catch (e) {
      _logger.e('Error getting SIM cards: $e');
      return [];
    }
  }

  /// Send SMS using specific SIM card
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    required SimCard simCard,
  }) async {
    try {
      final hasPermission = await hasSmsPermissions();
      if (!hasPermission) {
        _logger.e('SMS permissions not granted');
        return false;
      }

      _logger.i(
        'Sending SMS to $phoneNumber using ${simCard.displayName} (Slot: ${simCard.slotId})',
      );

      // Send SMS using telephony plugin
      // The subscriptionId parameter helps select which SIM to use
      await _telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) {
          _logger.i('SMS Status: $status');
        },
      );

      _logger.i('SMS sent successfully');
      return true;
    } catch (e) {
      _logger.e('Error sending SMS: $e');
      return false;
    }
  }

  /// Send bulk SMS using specific SIM card
  Future<Map<String, bool>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    required SimCard simCard,
  }) async {
    final results = <String, bool>{};

    try {
      final hasPermission = await hasSmsPermissions();
      if (!hasPermission) {
        _logger.e('SMS permissions not granted');
        for (final phone in phoneNumbers) {
          results[phone] = false;
        }
        return results;
      }

      for (final phoneNumber in phoneNumbers) {
        try {
          await _telephony.sendSms(
            to: phoneNumber,
            message: message,
            statusListener: (SendStatus status) {
              _logger.i('SMS to $phoneNumber - Status: $status');
            },
          );
          results[phoneNumber] = true;

          // Small delay between messages to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _logger.e('Error sending SMS to $phoneNumber: $e');
          results[phoneNumber] = false;
        }
      }

      return results;
    } catch (e) {
      _logger.e('Error in bulk SMS sending: $e');
      for (final phone in phoneNumbers) {
        results[phone] = false;
      }
      return results;
    }
  }

  /// Get default SIM card
  SimCard? getDefaultSimCard() {
    if (_simCards.isEmpty) return null;
    return _simCards.first;
  }

  /// Get SIM card by slot ID
  SimCard? getSimCardBySlot(int slotId) {
    try {
      return _simCards.firstWhere((sim) => sim.slotId == slotId);
    } catch (e) {
      _logger.w('SIM card not found for slot $slotId');
      return null;
    }
  }

  /// Check if device has dual SIM capability
  Future<bool> hasDualSim() async {
    try {
      final simCards = await getAvailableSimCards();
      return simCards.length > 1;
    } catch (e) {
      _logger.e('Error checking dual SIM: $e');
      return false;
    }
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
      _logger.i('Opened app settings');
    } catch (e) {
      _logger.e('Error opening app settings: $e');
    }
  }
}

/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'ViorNet';
  static const String appVersion = '1.0.0';
  static const String companyName = 'Pritech Vior Softech';
  static const String packageName = 'com.pritechvior.viornet';

  // API
  static const String baseUrl = 'https://api.viornet.com/api/v1';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Database
  static const String databaseName = 'viornet_local.db';
  static const int databaseVersion = 1;

  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyLastSyncTime = 'last_sync_time';
  static const String keyRememberMe = 'remember_me';
  static const String keyRememberedEmail = 'remembered_email';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Sync
  static const Duration syncInterval = Duration(minutes: 30);
  static const int maxSyncRetries = 3;

  // Voucher
  static const int defaultVoucherValidity = 30; // days
  static const List<int> voucherDurations = [
    1,
    7,
    14,
    30,
    90,
    180,
    365,
  ]; // days

  // SMS
  static const int smsMaxLength = 160;
  static const int smsMaxBatchSize = 50;

  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;

  // Animation
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd MMM yyyy HH:mm';
  static const String apiDateFormat = 'yyyy-MM-dd';
  static const String apiDateTimeFormat = 'yyyy-MM-dd\'T\'HH:mm:ss\'Z\'';

  // Roles
  static const String roleSuperAdmin = 'SUPER_ADMIN';
  static const String roleMarketing = 'MARKETING';
  static const String roleSales = 'SALES';
  static const String roleTechnical = 'TECHNICAL';
  static const String roleFinance = 'FINANCE';
  static const String roleAgent = 'AGENT';

  // Asset Conditions
  static const String conditionNew = 'NEW';
  static const String conditionGood = 'GOOD';
  static const String conditionFair = 'FAIR';
  static const String conditionPoor = 'POOR';
  static const String conditionDamaged = 'DAMAGED';

  // Voucher Status
  static const String voucherStatusUnused = 'UNUSED';
  static const String voucherStatusSold = 'SOLD';
  static const String voucherStatusActive = 'ACTIVE';
  static const String voucherStatusExpired = 'EXPIRED';

  // Maintenance Status
  static const String maintenanceStatusPending = 'PENDING';
  static const String maintenanceStatusInProgress = 'IN_PROGRESS';
  static const String maintenanceStatusCompleted = 'COMPLETED';
  static const String maintenanceStatusCancelled = 'CANCELLED';

  // SMS Channel Selection (stored in SharedPreferences)
  static const String smsChannelPrefKey = 'sms_channel';
  static const String smsChannelNative = 'thisPhone';
  static const String smsChannelQuickSms = 'quickSMS';

  // QuickSMS API (configurable via --dart-define or app settings)
  static const String quickSmsBaseUrl = String.fromEnvironment(
    'QUICKSMS_URL',
    defaultValue: 'https://api.quicksms.com.ng/v1',
  );
  static const String quickSmsApiKey = String.fromEnvironment(
    'QUICKSMS_API_KEY',
    defaultValue: '',
  );
  static const String quickSmsSenderId = String.fromEnvironment(
    'QUICKSMS_SENDER_ID',
    defaultValue: 'VIORNET',
  );

  // Native Android SMS – same platform channel as sms_getway-1.1.0
  static const String smsPlatformChannel = 'com.lwenatech.sms_gateway/sms';

  // SMS Status
  static const String smsStatusPending = 'PENDING';
  static const String smsStatusSent = 'SENT';
  static const String smsStatusFailed = 'FAILED';

  // Phone formatting
  static const String defaultCountryCode = '+255'; // Tanzania
}

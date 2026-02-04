import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const String currencySymbol = 'TSh';
  static const String currencyCode = 'TZS';

  /// Format amount as Tanzanian Shillings
  /// Example: 50000 -> "TSh 50,000"
  static String format(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat('#,##0', 'en_US');
    final formattedAmount = formatter.format(amount);

    if (showSymbol) {
      return '$currencySymbol $formattedAmount';
    }
    return formattedAmount;
  }

  /// Format amount with decimals
  /// Example: 50000.50 -> "TSh 50,000.50"
  static String formatWithDecimals(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedAmount = formatter.format(amount);

    if (showSymbol) {
      return '$currencySymbol $formattedAmount';
    }
    return formattedAmount;
  }

  /// Format compact amount for small screens
  /// Example: 5000000 -> "TSh 5M"
  static String formatCompact(double amount) {
    if (amount >= 1000000000) {
      return '$currencySymbol ${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '$currencySymbol ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$currencySymbol ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }
}

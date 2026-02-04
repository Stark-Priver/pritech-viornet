import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final Logger _logger = Logger();

  // Check current connectivity status
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.first != ConnectivityResult.none;
    } catch (e) {
      _logger.e('Error checking connectivity', error: e);
      return false;
    }
  }

  // Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  // Check if WiFi is connected
  Future<bool> isWifiConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.wifi);
    } catch (e) {
      _logger.e('Error checking WiFi connectivity', error: e);
      return false;
    }
  }

  // Check if mobile data is connected
  Future<bool> isMobileConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.mobile);
    } catch (e) {
      _logger.e('Error checking mobile connectivity', error: e);
      return false;
    }
  }
}

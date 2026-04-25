import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

enum ConnectionStatus { online, offline, unknown }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus _currentStatus = ConnectionStatus.unknown;
  ConnectionStatus get currentStatus => _currentStatus;

  ConnectivityService() {
    _init();
  }

  void _init() {
    // NEW: onConnectivityChanged now returns List<ConnectivityResult>
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });

    checkConnectivity();
  }

  Future<void> checkConnectivity() async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If ANY result is not "none", we're online
    final bool hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );

    ConnectionStatus newStatus =
        hasConnection ? ConnectionStatus.online : ConnectionStatus.offline;

    if (newStatus == ConnectionStatus.offline) {
      AppLogger.warning('Device is OFFLINE – switching to Bluetooth mode');
    } else {
      AppLogger.success('Device is ONLINE – using Firebase/Internet');
    }

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  bool get isOnline => _currentStatus == ConnectionStatus.online;
  bool get isOffline => _currentStatus == ConnectionStatus.offline;

  void dispose() {
    _statusController.close();
  }
}
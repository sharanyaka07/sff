import 'package:flutter/foundation.dart';
import '../../../core/services/user_preferences.dart';
import '../../../data/local/database/db_helper.dart';
import '../../../data/local/models/sos_log_model.dart';
import '../../../core/utils/logger.dart';

class HomeController extends ChangeNotifier {
  String _userName = 'User';
  String get userName => _userName;

  int _messageCount = 0;
  int get messageCount => _messageCount;

  List<SosLog> _recentSosLogs = [];
  List<SosLog> get recentSosLogs => _recentSosLogs;

  bool _loading = false;
  bool get loading => _loading;

  // ── Load all dashboard data ──────────────────────────────────────
  Future<void> loadDashboard() async {
    if (_loading) return; // prevent duplicate calls
    _loading = true;
    notifyListeners();

    try {
      // Load user name
      _userName = await UserPreferences.getUserName();
    } catch (e) {
      AppLogger.error('Failed to load user name', tag: 'HOME', error: e);
      _userName = 'User';
    }

    try {
      // Load message count
      _messageCount = await DbHelper.getMessageCount();
    } catch (e) {
      AppLogger.error('Failed to load message count', tag: 'HOME', error: e);
      _messageCount = 0;
    }

    try {
      // Load recent SOS logs — show only last 3 on dashboard
      final allLogs = await DbHelper.getSosLogs();
      _recentSosLogs = allLogs.take(3).toList();
    } catch (e) {
      AppLogger.error('Failed to load SOS logs', tag: 'HOME', error: e);
      _recentSosLogs = [];
    }

    AppLogger.info(
      'Dashboard loaded — user: $_userName, msgs: $_messageCount, sos: ${_recentSosLogs.length}',
      tag: 'HOME',
    );

    _loading = false;
    notifyListeners();
  }

  // ── Refresh (pull-to-refresh) ────────────────────────────────────
  Future<void> refresh() => loadDashboard();
}
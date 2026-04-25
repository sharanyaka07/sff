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

  bool _loading = true;
  bool get loading => _loading;

  // ── Load all dashboard data ──────────────────────────────────────
  Future<void> loadDashboard() async {
    _loading = true;
    notifyListeners();

    try {
      _userName = await UserPreferences.getUserName();
      _messageCount = await DbHelper.getMessageCount();

      final allLogs = await DbHelper.getSosLogs();
      // Show only last 3 SOS logs on dashboard
      _recentSosLogs = allLogs.take(3).toList();

      AppLogger.info('Dashboard loaded ✅', tag: 'HOME');
    } catch (e) {
      AppLogger.error('Dashboard load failed', tag: 'HOME', error: e);
    }

    _loading = false;
    notifyListeners();
  }

  // ── Refresh ──────────────────────────────────────────────────────
  Future<void> refresh() => loadDashboard();
}
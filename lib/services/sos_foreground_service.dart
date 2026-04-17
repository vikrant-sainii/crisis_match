import 'dart:developer' as developer;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used to share data between UI and background
class SosPrefsKeys {
  static const victimId = 'sos_victim_id';
  static const isEnabled = 'sos_is_enabled';
}

/// Manages the Android foreground service that keeps the app alive
/// when minimized, providing a persistent notification.
class SosForegroundService {
  /// Persist victimId.
  static Future<void> saveVictimId(String victimId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SosPrefsKeys.victimId, victimId);
  }

  /// Initialize and start the foreground service with a persistent notification.
  static Future<void> startService({
    required String wakeWord, // legacy param, ignored
    required String victimId,
    required void Function() onWakeWordDetected, // legacy param, ignored
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SosPrefsKeys.victimId, victimId);
    await prefs.setBool(SosPrefsKeys.isEnabled, true);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sos_channel',
        channelName: 'CrisisMatch SOS',
        channelDescription: 'Power button emergency detection',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    final result = await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '🛡️ CrisisMatch SOS Active',
      notificationText: 'Shake violently × 4 or click below',
      callback: _startCallback,
    );

    developer.log(
        'SosForegroundService: Start result=$result victim=$victimId');
  }

  /// Stop the foreground service and remove the notification.
  static Future<void> stopService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SosPrefsKeys.isEnabled, false);
    await FlutterForegroundTask.stopService();
    developer.log('SosForegroundService: Stopped');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level callback — MUST be a top-level function with vm:entry-point
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_DummyTaskHandler());
}

class _DummyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

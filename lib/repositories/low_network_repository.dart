import 'dart:io';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

enum ConnectivityStatus { online, lowNetwork, offline }

class LowNetworkRepository {
  static const String emergencyNumber = "+1 825 773 4711";
  final Telephony telephony = Telephony.instance;
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _internetChecker = InternetConnectionChecker();

  Stream<ConnectivityStatus> get statusStream async* {
    yield await _currentStatus();
    // In connectivity_plus 6.0+, this is a Stream<List<ConnectivityResult>>
    await for (final _ in _connectivity.onConnectivityChanged) {
      yield await _currentStatus();
    }
  }

  Future<ConnectivityStatus> _currentStatus() async {
    // In connectivity_plus 6.0+, this returns List<ConnectivityResult>
    final results = await _connectivity.checkConnectivity();
    
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return ConnectivityStatus.offline;
    }
    
    final hasUplink = await _internetChecker.hasConnection;
    if (!hasUplink) return ConnectivityStatus.offline;

    // Check latency for "Low Network" status
    final latency = await getLatency();
    if (latency > 800) return ConnectivityStatus.lowNetwork;
    
    return ConnectivityStatus.online;
  }

  Future<int> getLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      final hasConnection = await _internetChecker.hasConnection;
      stopwatch.stop();
      return hasConnection ? stopwatch.elapsedMilliseconds : 9999;
    } catch (_) {
      return 9999;
    }
  }

  /// Check if we have a real internet uplink
  Future<bool> hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      // internet_connection_checker does a real ping to verify uplink
      return await InternetConnectionChecker().hasConnection;
    } catch (e) {
      developer.log('LowNetworkRepo: Connectivity check failed: $e');
      return false;
    }
  }

  /// Format the SMS message exactly as requested
  String formatSosMessage({
    required String victimId,
    required double lat,
    required double lng,
    required String message,
    required String priority,
  }) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);

    return '''
HELP NEEDED 🚨
ID: $victimId
LAT: ${lat.toStringAsFixed(6)}
LONG: ${lng.toStringAsFixed(6)}
TIME: $timeStr
MSG: ${message.trim().isEmpty ? "Emergency SOS Triggered" : message}
PRIORITY: ${priority.toUpperCase()}
''';
  }

  /// Send the emergency SMS
  /// iOS: Opens message app with pre-filled text
  /// Android: Sends in background if possible
  Future<void> sendEmergencySms(String body) async {
    if (Platform.isAndroid) {
      try {
        final bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
        if (permissionsGranted == true) {
          // Send SMS in background (silent)
          await telephony.sendSms(
            to: emergencyNumber,
            message: body,
            statusListener: (status) {
              developer.log('LowNetworkRepo: SMS status update: $status');
            },
          );
          developer.log('LowNetworkRepo: SMS sent via Telephony (Android)');
          return;
        } else {
          developer.log('LowNetworkRepo: SMS permissions denied, falling back to intent');
          await _launchSmsIntent(body);
        }
      } catch (e) {
        developer.log('LowNetworkRepo: Android background SMS failed: $e');
        await _launchSmsIntent(body);
      }
    } else {
      // iOS doesn't allow background SMS
      await _launchSmsIntent(body);
    }
  }

  Future<void> _launchSmsIntent(String body) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: emergencyNumber,
      queryParameters: <String, String>{
        'body': body,
      },
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
      developer.log('LowNetworkRepo: SMS intent launched');
    } else {
      throw 'Could not launch SMS intent';
    }
  }
}

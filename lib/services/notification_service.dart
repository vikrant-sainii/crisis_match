import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Initialize notifications: request permissions and setup listeners
  Future<void> initialize() async {
    // 1. Request permissions (especially for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted notification permissions');
    } else {
      developer.log('User declined or has not accepted notification permissions');
    }

    // 2. Get the initial token
    await _saveTokenToDatabase();

    // 3. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _updateTokenInSupabase(newToken);
    });

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Received foreground message: ${message.notification?.title}');
      // You could show a local notification or snackbar here
    });

    // 5. Handle clicks (when app is in background but opened via notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('App opened via notification: ${message.data}');
    });
  }

  /// Helper to get current token and save it
  Future<void> _saveTokenToDatabase() async {
    String? token = await _fcm.getToken();
    if (token != null) {
      developer.log('FCM Token: $token');
      await _updateTokenInSupabase(token);
    }
  }

  /// Update the token in Supabase profiles table
  Future<void> _updateTokenInSupabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({
          'fcm_token': token,
        }).eq('id', user.id);
        developer.log('FCM token updated in Supabase for user ${user.id}');
      } catch (e) {
        developer.log('Error updating FCM token in Supabase: $e');
      }
    }
  }
}

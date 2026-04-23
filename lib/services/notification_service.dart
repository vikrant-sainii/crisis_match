import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';


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
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `onMessage` is triggered with a notification, construct our own
      // local notification to show to users using the created channel.
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              // other properties...
            ),
          ),
        );
      }
    });

    // 5. Handle clicks (when app is in background but opened via notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('App opened via notification: ${message.data}');
    });
  }

  /// Helper to get current token and save it
  Future<void> _saveTokenToDatabase() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        developer.log('FCM Token: $token');
        await _updateTokenInSupabase(token);
      }
    } catch (e) {
      developer.log('FCM Token error: $e');
      // On iOS simulators, this is expected as they don't support push notifications.
      // On real devices, it might mean APNS is still initializing.
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

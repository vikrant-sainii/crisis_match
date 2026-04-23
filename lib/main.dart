import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'repositories/auth_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/help_request_repository.dart';
import 'repositories/helper_repository.dart';
import 'repositories/location_repository.dart';
import 'repositories/low_network_repository.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/help_request/help_request_bloc.dart';
import 'blocs/location/location_bloc.dart';
import 'blocs/admin/admin_bloc.dart';
import 'repositories/leaderboard_repository.dart';
import 'blocs/leaderboard/leaderboard_bloc.dart';
import 'blocs/connectivity/connectivity_bloc.dart';
import 'blocs/connectivity/connectivity_event.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Update FCM settings for foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Create repositories
  final authRepository = AuthRepository();
  final helperRepository = HelperRepository();
  final helpRequestRepository = HelpRequestRepository();
  final chatRepository = ChatRepository();
  final locationRepository = LocationRepository();
  final lowNetworkRepository = LowNetworkRepository();
  final leaderboardRepository = LeaderboardRepository(Supabase.instance.client);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: helperRepository),
        RepositoryProvider.value(value: helpRequestRepository),
        RepositoryProvider.value(value: chatRepository),
        RepositoryProvider.value(value: locationRepository),
        RepositoryProvider.value(value: lowNetworkRepository),
        RepositoryProvider.value(value: leaderboardRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectivityBloc(
              repository: lowNetworkRepository,
            )..add(ObserveConnectivity()),
          ),
          BlocProvider(
            create: (_) => AuthBloc(
              authRepository: authRepository,
              helperRepository: helperRepository,
              locationRepository: locationRepository,
              lowNetworkRepo: lowNetworkRepository,
            )..add(AuthCheckStatus()),
          ),
          BlocProvider(
            create: (_) => HelpRequestBloc(
              repository: helpRequestRepository,
            ),
          ),
          BlocProvider(
            create: (_) => ChatBloc(
              repository: chatRepository,
            ),
          ),
          BlocProvider(
            create: (_) => LocationBloc(
              repository: locationRepository,
            ),
          ),
          BlocProvider(
            create: (_) => AdminBloc(
              authRepository: authRepository,
              helperRepository: helperRepository,
              helpRequestRepository: helpRequestRepository,
            ),
          ),
          BlocProvider(
            create: (_) => LeaderboardBloc(
              repository: leaderboardRepository,
            ),
          ),
        ],
        child: const App(),
      ),
    ),
  );
}

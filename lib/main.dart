import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'repositories/auth_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/help_request_repository.dart';
import 'repositories/helper_repository.dart';
import 'repositories/location_repository.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/help_request/help_request_bloc.dart';
import 'blocs/location/location_bloc.dart';
import 'blocs/admin/admin_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: helperRepository),
        RepositoryProvider.value(value: helpRequestRepository),
        RepositoryProvider.value(value: chatRepository),
        RepositoryProvider.value(value: locationRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(
              authRepository: authRepository,
              helperRepository: helperRepository,
              locationRepository: locationRepository,
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
        ],
        child: const App(),
      ),
    ),
  );
}

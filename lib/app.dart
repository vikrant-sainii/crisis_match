import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/notification_service.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/victim/victim_home_screen.dart';
import 'screens/helper/helper_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

import 'blocs/connectivity/connectivity_bloc.dart';
import 'blocs/connectivity/connectivity_state.dart';
import 'repositories/low_network_repository.dart';
import 'widgets/connectivity_visualizer.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisMatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            NotificationService().initialize();
          }
        },
        child: ConnectivityVisualizer(
          child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
            builder: (context, connState) {
              return BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  // 1. Authenticated Users (Always prioritize Home)
                  if (authState is AuthAuthenticated) {
                    if (authState.profile.role == 'helper') return const HelperHomeScreen();
                    if (authState.profile.role == 'admin') return const AdminHomeScreen();
                    return const VictimHomeScreen();
                  }

                  // 2. Initial State (Show Loading)
                  if (authState is AuthInitial || connState is ConnectivityInitial) {
                    return const Scaffold(
                      backgroundColor: Color(0xFF0F172A),
                      body: Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE))),
                    );
                  }

                  // 3. Offline Handling (Even if unauthenticated, show Victim Home as Guest)
                  if (connState.status == ConnectivityStatus.offline || authState is AuthOfflineGuest) {
                    return const VictimHomeScreen();
                  }

                  // 4. Default to Login (Only if online and unauthenticated)
                  return const LoginScreen();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

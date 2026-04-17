import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/victim/victim_home_screen.dart';
import 'screens/helper/helper_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

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
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            if (state.profile.role == 'helper') {
              return const HelperHomeScreen();
            }
            if (state.profile.role == 'admin') {
              return const AdminHomeScreen();
            }
            return const VictimHomeScreen();
          }
          
          if (state is AuthInitial) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Fallback for AuthUnauthenticated, AuthBlocked, AuthError, and AuthLoading
          // LoginScreen and SignupScreen handle their own loading/error UI internal to their widget tree.
          return const LoginScreen();
        },
      ),
    );
  }
}

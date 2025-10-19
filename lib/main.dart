import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/supabase_service.dart';
import 'repositories/auth_repository.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'bloc/auth_state.dart' as auth_states;
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize AuthRepository
  await AuthRepository.instance.initialize();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AuthBloc(authRepository: AuthRepository.instance)
            ..add(const AuthCheckRequested()),
      child: MaterialApp(
        title: 'Sistema de Almacenes',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        if (state is auth_states.AuthLoading ||
            state is auth_states.AuthInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (state is auth_states.AuthAuthenticated) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

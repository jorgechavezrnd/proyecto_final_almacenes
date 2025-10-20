import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/supabase_service.dart';
import 'repositories/auth_repository.dart';
import 'repositories/inventory_repository.dart';
import 'blocs/auth_bloc.dart';
import 'blocs/auth_event.dart';
import 'blocs/warehouse_bloc.dart';
import 'blocs/product_bloc.dart';
import 'blocs/sales_bloc.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'blocs/auth_state.dart' as auth_states;
import 'config/supabase_config.dart';
import 'database/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize AuthRepository
  await AuthRepository.instance.initialize();

  // Initialize database and InventoryRepository
  final database = AppDatabase();
  await InventoryRepository.instance.initialize(database);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              AuthBloc(authRepository: AuthRepository.instance)
                ..add(const AuthCheckRequested()),
        ),
        BlocProvider(
          create: (context) =>
              WarehouseBloc(repository: InventoryRepository.instance),
        ),
        BlocProvider(
          create: (context) =>
              ProductBloc(repository: InventoryRepository.instance),
        ),
        BlocProvider(
          create: (context) => SalesBloc(InventoryRepository.instance),
        ),
      ],
      child: MaterialApp(
        title: 'Sistema de Almacenes',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'), // Español
          Locale('en', 'US'), // English
        ],
        locale: const Locale('es', 'ES'),
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

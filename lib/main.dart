import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // If .env file doesn't exist, continue without it (using defaults)
  }

  // Initialize Supabase with environment variables
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
          create: (context) =>
              SalesBloc(InventoryRepository.instance, AuthRepository.instance),
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
    return BlocConsumer<AuthBloc, auth_states.AuthState>(
      listener: (context, state) {
        if (state is auth_states.AuthError) {
          // Handle email confirmation error with dialog
          if (state.message.contains('confirmar tu correo') ||
              state.message.contains('📧')) {
            _showEmailConfirmationDialog(context, state.message);
          } else {
            // Show regular error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
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

  void _showEmailConfirmationDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, color: Colors.orange, size: 40),
              const SizedBox(height: 8),
              const Text(
                'Email no confirmado',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'También revisa tu carpeta de spam',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../database/database.dart';
import '../database/user_session_dao.dart';

/// Repository that manages authentication state combining Supabase and local Drift storage
class AuthRepository {
  static AuthRepository? _instance;
  static AuthRepository get instance => _instance ??= AuthRepository._();

  AuthRepository._();

  late final AppDatabase _database;
  late final UserSessionDao _sessionDao;
  final SupabaseService _supabaseService = SupabaseService.instance;

  /// Initialize the repository with database
  Future<void> initialize() async {
    _database = AppDatabase();
    _sessionDao = UserSessionDao(_database);

    // Clean expired sessions on startup
    await _sessionDao.cleanExpiredSessions();

    // Listen to Supabase auth state changes
    _supabaseService.authStateChanges.listen(_handleAuthStateChange);
  }

  /// Dispose database connection
  Future<void> dispose() async {
    await _database.close();
  }

  /// Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      // Check if user was created successfully
      if (response.user != null) {
        // If there's a session, user is immediately confirmed
        if (response.session != null) {
          await _sessionDao.saveSession(response.session!, response.user!);
          return AuthResult.success(response.user!);
        } else {
          // User created but needs email confirmation
          return AuthResult.emailConfirmationRequired(email);
        }
      }

      return AuthResult.error(
        'Error en el registro: no se pudo crear el usuario',
      );
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.session != null && response.user != null) {
        await _sessionDao.saveSession(response.session!, response.user!);
        return AuthResult.success(response.user!);
      }

      return AuthResult.error('Inicio de sesión fallido: sesión no creada');
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Sign out user
  Future<AuthResult> signOut() async {
    try {
      await _supabaseService.signOut();
      await _sessionDao.deleteAllSessions();
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Reset password
  Future<AuthResult> resetPassword({
    required String email,
    String? redirectUrl,
  }) async {
    try {
      await _supabaseService.resetPassword(
        email: email,
        redirectUrl: redirectUrl,
      );
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Get current authenticated user
  Future<User?> getCurrentUser() async {
    // First check Supabase session
    final supabaseUser = _supabaseService.currentUser;
    if (supabaseUser != null) {
      return supabaseUser;
    }

    // If no Supabase session, check local session
    final localSession = await _sessionDao.getCurrentSession();
    if (localSession != null) {
      // Try to refresh the session
      try {
        final response = await _supabaseService.refreshSession();
        if (response.session != null && response.user != null) {
          await _sessionDao.updateSession(response.session!, response.user!);
          return response.user;
        }
      } catch (e) {
        // If refresh fails, clear local session
        await _sessionDao.deleteSession(localSession.id);
      }
    }

    return null;
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null;
  }

  /// Get user role
  Future<String?> getUserRole() async {
    // First try from Supabase
    final supabaseRole = _supabaseService.getUserRole();
    if (supabaseRole != null) {
      return supabaseRole;
    }

    // Then try from local session
    return await _sessionDao.getUserRole();
  }

  /// Get user metadata
  Future<Map<String, dynamic>?> getUserMetadata() async {
    final user = await getCurrentUser();
    if (user?.userMetadata != null) {
      return user!.userMetadata;
    }

    // Fallback to local session
    return await _sessionDao.getUserMetadata();
  }

  /// Update user profile
  Future<AuthResult> updateProfile({Map<String, dynamic>? data}) async {
    try {
      final response = await _supabaseService.updateProfile(data: data);
      if (response.user != null) {
        // Update local session if exists
        final session = _supabaseService.currentSession;
        if (session != null) {
          await _sessionDao.updateSession(session, response.user!);
        }
        return AuthResult.success(response.user!);
      }
      return AuthResult.error('Error actualizando perfil');
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Handle auth state changes from Supabase
  void _handleAuthStateChange(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        if (state.session != null) {
          await _sessionDao.saveSession(state.session!, state.session!.user);
        }
        break;
      case AuthChangeEvent.signedOut:
        await _sessionDao.deleteAllSessions();
        break;
      case AuthChangeEvent.tokenRefreshed:
        if (state.session != null) {
          await _sessionDao.updateSession(state.session!, state.session!.user);
        }
        break;
      default:
        break;
    }
  }

  /// Get auth state changes stream
  Stream<AuthState> get authStateChanges => _supabaseService.authStateChanges;
}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String? error;
  final User? user;
  final bool requiresEmailConfirmation;

  AuthResult._({
    required this.isSuccess,
    this.error,
    this.user,
    this.requiresEmailConfirmation = false,
  });

  factory AuthResult.success(User? user) {
    return AuthResult._(isSuccess: true, user: user);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }

  factory AuthResult.emailConfirmationRequired(String email) {
    return AuthResult._(
      isSuccess: true,
      requiresEmailConfirmation: true,
      error:
          'Se ha enviado un email de confirmación a $email. Por favor, revisa tu bandeja de entrada y confirma tu cuenta.',
    );
  }
}

/// Extension to get user display name
extension UserExtension on User {
  String get displayName {
    if (userMetadata?['full_name'] != null) {
      return userMetadata!['full_name'] as String;
    }
    if (userMetadata?['name'] != null) {
      return userMetadata!['name'] as String;
    }
    return email?.split('@').first ?? 'Usuario';
  }
}

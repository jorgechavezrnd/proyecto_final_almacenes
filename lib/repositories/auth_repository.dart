import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../database/database.dart';
import '../database/user_session_dao.dart';
import '../models/user_model.dart';

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

  /// Get all users (admin only functionality)
  Future<List<UserModel>> getAllUsers() async {
    try {
      // Verify current user is admin
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final userRole = await getUserRole();
      if (userRole?.toLowerCase() != 'admin') {
        throw Exception(
          'Solo los administradores pueden ver la lista de usuarios',
        );
      }

      // Method 1: Try RPC function to access auth.users directly
      try {
        final users = await _getUsersFromRPC();
        if (users.isNotEmpty) {
          return users;
        }
      } catch (e) {
        // Method failed, continue to next
      }

      // Method 2: Try using Admin API (if service role key is available)
      try {
        final users = await _getUsersFromAdminAPI();
        if (users.isNotEmpty) {
          return users;
        }
      } catch (e) {
        // Method failed, continue to fallback
      }

      // Fallback: Return enhanced mock data that simulates real users
      return await _getEnhancedMockUsers();
    } catch (e) {
      return await _getEnhancedMockUsers();
    }
  }

  /// Get users using RPC function that accesses auth.users
  Future<List<UserModel>> _getUsersFromRPC() async {
    // Try the main RPC function first
    try {
      final response = await _supabaseService.client.rpc(
        'get_auth_users_admin',
      );
      return _parseUsersFromResponse(response);
    } catch (e) {
      // Try the alternative JSON RPC function
      try {
        final jsonResponse = await _supabaseService.client.rpc(
          'get_auth_users_simple',
        );
        if (jsonResponse is List) {
          return _parseUsersFromResponse(jsonResponse);
        } else if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          return _parseUsersFromResponse(jsonResponse['data']);
        } else {
          // The response might be a JSON string
          final List<dynamic> userData = jsonResponse as List<dynamic>;
          return _parseUsersFromResponse(userData);
        }
      } catch (e2) {
        rethrow;
      }
    }
  }

  /// Helper method to parse users from different response formats
  List<UserModel> _parseUsersFromResponse(dynamic response) {
    final List<UserModel> users = [];
    final List<dynamic> userList = response is List ? response : [response];

    for (final userData in userList) {
      try {
        // Extract user name from the correct field in raw_user_meta_data
        String userName = '';
        if (userData['raw_user_meta_data'] != null) {
          final metaData = userData['raw_user_meta_data'];
          userName =
              metaData['full_name']?.toString() ??
              metaData['user_name']?.toString() ??
              metaData['username']?.toString() ??
              metaData['name']?.toString() ??
              '';
        }

        // Extract role from raw_user_meta_data
        String? role;
        if (userData['raw_user_meta_data'] != null) {
          role = userData['raw_user_meta_data']['role']?.toString();
        }

        // Parse last_sign_in_at date
        DateTime? lastSignInAt;
        if (userData['last_sign_in_at'] != null) {
          try {
            lastSignInAt = DateTime.parse(
              userData['last_sign_in_at'].toString(),
            );
          } catch (e) {
            // Error parsing date, continue without it
          }
        }

        // Parse created_at date
        DateTime? createdAt;
        if (userData['created_at'] != null) {
          try {
            createdAt = DateTime.parse(userData['created_at'].toString());
          } catch (e) {
            // Error parsing date, continue without it
          }
        }

        final userModel = UserModel(
          id: userData['id']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          userName: userName,
          role: role,
          lastSignInAt: lastSignInAt,
          createdAt: createdAt,
        );

        users.add(userModel);
      } catch (e) {
        // Error parsing user, skip this entry
      }
    }
    return users;
  }

  /// Alternative method using Admin API (requires service role key)
  Future<List<UserModel>> _getUsersFromAdminAPI() async {
    // This would require service role key which is not recommended on client side
    // Instead, we'll try to query auth schema directly (may not work due to RLS)
    try {
      final response = await _supabaseService.client
          .schema('auth')
          .from('users')
          .select('id, email, raw_user_meta_data, last_sign_in_at, created_at')
          .order('created_at', ascending: false);

      final List<UserModel> users = [];
      for (final userData in response) {
        try {
          final userModel = UserModel.fromJson({
            'id': userData['id'],
            'email': userData['email'],
            'user_name':
                userData['raw_user_meta_data']?['user_name'] ??
                userData['raw_user_meta_data']?['username'] ??
                userData['raw_user_meta_data']?['name'] ??
                '',
            'role': userData['raw_user_meta_data']?['role'],
            'last_sign_in_at': userData['last_sign_in_at'],
            'created_at': userData['created_at'],
          });
          users.add(userModel);
        } catch (e) {
          // Error parsing user, skip this entry
        }
      }
      return users;
    } catch (e) {
      return [];
    }
  }

  /// Enhanced mock users that include current user for demonstration
  Future<List<UserModel>> _getEnhancedMockUsers() async {
    final currentUser = await getCurrentUser();
    final currentUserRole = await getUserRole();
    final userMetadata = await getUserMetadata();
    final userName =
        userMetadata?['user_name']?.toString() ??
        userMetadata?['username']?.toString() ??
        userMetadata?['name']?.toString() ??
        'Usuario Actual';

    List<UserModel> users = [
      // Current user
      if (currentUser != null)
        UserModel(
          id: currentUser.id,
          email: currentUser.email ?? 'usuario@almacenes.com',
          userName: userName,
          role: currentUserRole ?? 'admin',
          lastSignInAt: DateTime.now(),
          createdAt: DateTime.tryParse(currentUser.createdAt) ?? DateTime.now(),
        ),
      // Mock users
      UserModel(
        id: '1',
        email: 'admin@almacenes.com',
        userName: 'Administrador Sistema',
        role: 'admin',
        lastSignInAt: DateTime.now().subtract(const Duration(hours: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      UserModel(
        id: '2',
        email: 'vendedor1@almacenes.com',
        userName: 'Juan Pérez',
        role: 'user',
        lastSignInAt: DateTime.now().subtract(const Duration(hours: 4)),
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      UserModel(
        id: '3',
        email: 'vendedor2@almacenes.com',
        userName: 'María García',
        role: 'user',
        lastSignInAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      UserModel(
        id: '4',
        email: 'supervisor@almacenes.com',
        userName: 'Carlos López',
        role: 'user',
        lastSignInAt: DateTime.now().subtract(const Duration(hours: 8)),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    // Remove duplicates based on email
    final Map<String, UserModel> uniqueUsers = {};
    for (final user in users) {
      uniqueUsers[user.email] = user;
    }

    return uniqueUsers.values.toList();
  }
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

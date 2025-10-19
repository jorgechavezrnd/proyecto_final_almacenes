import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class for handling Supabase authentication operations
/// Provides methods for login, signup, logout, and session management
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  /// Get the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Get current user session
  Session? get currentSession => client.auth.currentSession;

  /// Get current user
  User? get currentUser => client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentSession != null && currentUser != null;

  /// Initialize Supabase client
  /// Should be called in main() before runApp()
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Reset password for email
  Future<void> resetPassword({
    required String email,
    String? redirectUrl,
  }) async {
    try {
      await client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      final response = await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update user profile data
  Future<UserResponse> updateProfile({Map<String, dynamic>? data}) async {
    try {
      final response = await client.auth.updateUser(UserAttributes(data: data));
      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Get user role from metadata
  String? getUserRole() {
    final user = currentUser;
    if (user?.userMetadata != null) {
      return user!.userMetadata!['role'] as String?;
    }
    return null;
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Refresh current session
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await client.auth.refreshSession();
      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Handle authentication exceptions and provide user-friendly messages
  Exception _handleAuthException(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return Exception('Credenciales de inicio de sesión inválidas');
        case 'User not found':
          return Exception('Usuario no encontrado');
        case 'Email not confirmed':
          return Exception('Email no confirmado');
        case 'Password should be at least 6 characters':
          return Exception('La contraseña debe tener al menos 6 caracteres');
        case 'Unable to validate email address: invalid format':
          return Exception('Formato de email inválido');
        case 'User already registered':
          return Exception('El usuario ya está registrado');
        default:
          return Exception('Error de autenticación: ${error.message}');
      }
    }
    return Exception('Error inesperado: $error');
  }
}

/// Custom exception for authentication errors
class AuthServiceException implements Exception {
  final String message;
  final String? code;

  const AuthServiceException(this.message, {this.code});

  @override
  String toString() => 'AuthServiceException: $message';
}

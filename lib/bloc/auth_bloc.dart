import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Authentication BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    // Register event handlers
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);
    on<AuthProfileUpdateRequested>(_onAuthProfileUpdateRequested);
    on<AuthStateChangeReceived>(_onAuthStateChangeReceived);

    // Listen to auth state changes
    _authStateSubscription = _authRepository.authStateChanges.listen((
      authState,
    ) {
      final isAuthenticated = authState.session != null;
      add(AuthStateChangeReceived(isAuthenticated: isAuthenticated));
    });
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }

  /// Handle auth check request
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final isAuthenticated = await _authRepository.isAuthenticated();

      if (isAuthenticated) {
        final user = await _authRepository.getCurrentUser();
        final role = await _authRepository.getUserRole();

        if (user != null) {
          emit(AuthAuthenticated(user: user, role: role));
        } else {
          emit(const AuthUnauthenticated());
        }
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle login request
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );

      if (result.isSuccess && result.user != null) {
        final role = await _authRepository.getUserRole();
        emit(AuthAuthenticated(user: result.user!, role: role));
      } else {
        emit(AuthError(message: result.error ?? 'Error de inicio de sesión'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle sign up request
  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        metadata: event.metadata,
      );

      if (result.isSuccess) {
        if (result.requiresEmailConfirmation) {
          emit(AuthEmailConfirmationRequired(email: event.email));
        } else if (result.user != null) {
          final role = await _authRepository.getUserRole();
          emit(AuthAuthenticated(user: result.user!, role: role));
        } else {
          emit(AuthError(message: result.error ?? 'Error de registro'));
        }
      } else {
        emit(AuthError(message: result.error ?? 'Error de registro'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle logout request
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authRepository.signOut();

      if (result.isSuccess) {
        emit(const AuthUnauthenticated());
      } else {
        emit(AuthError(message: result.error ?? 'Error al cerrar sesión'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle password reset request
  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authRepository.resetPassword(email: event.email);

      if (result.isSuccess) {
        emit(AuthPasswordResetSent(email: event.email));
      } else {
        emit(
          AuthError(
            message: result.error ?? 'Error enviando reset de contraseña',
          ),
        );
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle profile update request
  Future<void> _onAuthProfileUpdateRequested(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authRepository.updateProfile(data: event.data);

      if (result.isSuccess && result.user != null) {
        emit(AuthProfileUpdated(user: result.user!));

        // Return to authenticated state
        final role = await _authRepository.getUserRole();
        emit(AuthAuthenticated(user: result.user!, role: role));
      } else {
        emit(AuthError(message: result.error ?? 'Error actualizando perfil'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle auth state change from repository
  Future<void> _onAuthStateChangeReceived(
    AuthStateChangeReceived event,
    Emitter<AuthState> emit,
  ) async {
    if (event.isAuthenticated) {
      final user = await _authRepository.getCurrentUser();
      final role = await _authRepository.getUserRole();

      if (user != null) {
        emit(AuthAuthenticated(user: user, role: role));
      }
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  /// Helper method to get current user
  Future<supabase.User?> getCurrentUser() async {
    return await _authRepository.getCurrentUser();
  }

  /// Helper method to get user role
  Future<String?> getUserRole() async {
    return await _authRepository.getUserRole();
  }

  /// Helper method to check if user is authenticated
  bool get isAuthenticated => state is AuthAuthenticated;
}

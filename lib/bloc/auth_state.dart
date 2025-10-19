import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication states
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final User user;
  final String? role;

  const AuthAuthenticated({required this.user, this.role});

  @override
  List<Object?> get props => [user, role];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  final String email;

  const AuthPasswordResetSent({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthEmailConfirmationRequired extends AuthState {
  final String email;

  const AuthEmailConfirmationRequired({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthProfileUpdated extends AuthState {
  final User user;

  const AuthProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}

import 'package:equatable/equatable.dart';

/// Authentication events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final Map<String, dynamic>? metadata;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    this.metadata,
  });

  @override
  List<Object?> get props => [email, password, metadata];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthProfileUpdateRequested extends AuthEvent {
  final Map<String, dynamic> data;

  const AuthProfileUpdateRequested({required this.data});

  @override
  List<Object?> get props => [data];
}

class AuthStateChangeReceived extends AuthEvent {
  final bool isAuthenticated;

  const AuthStateChangeReceived({required this.isAuthenticated});

  @override
  List<Object?> get props => [isAuthenticated];
}

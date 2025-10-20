import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String userName;
  final String? role;
  final DateTime? lastSignInAt;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.userName,
    this.role,
    this.lastSignInAt,
    this.createdAt,
  });

  factory UserModel.fromSupabaseUser(
    dynamic user,
    Map<String, dynamic>? userMetadata,
  ) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      userName:
          userMetadata?['full_name']?.toString() ??
          userMetadata?['user_name']?.toString() ??
          userMetadata?['username']?.toString() ??
          userMetadata?['name']?.toString() ??
          '',
      role: userMetadata?['role']?.toString(),
      lastSignInAt: user.lastSignInAt != null
          ? DateTime.parse(user.lastSignInAt)
          : null,
      createdAt: user.createdAt != null ? DateTime.parse(user.createdAt) : null,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      userName:
          json['full_name'] ??
          json['user_name'] ??
          json['username'] ??
          json['name'] ??
          '',
      role: json['role'],
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.parse(json['last_sign_in_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'user_name': userName,
      'role': role,
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    email,
    userName,
    role,
    lastSignInAt,
    createdAt,
  ];
}

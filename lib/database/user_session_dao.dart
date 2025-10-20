import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database.dart';

/// Data Access Object for UserSession operations
class UserSessionDao {
  final AppDatabase _database;

  UserSessionDao(this._database);

  /// Get current user session from local database
  Future<UserSession?> getCurrentSession() async {
    final query = _database.select(_database.userSessions);
    final sessions = await query.get();

    if (sessions.isEmpty) return null;

    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final session = sessions.first;

    if (session.expiresAt.isBefore(DateTime.now())) {
      await deleteSession(session.id);
      return null;
    }

    return session;
  }

  /// Save user session to local database
  Future<void> saveSession(Session supabaseSession, User user) async {
    final userMetadata = user.userMetadata != null
        ? jsonEncode(user.userMetadata)
        : null;

    final sessionData = UserSessionsCompanion(
      id: Value(supabaseSession.accessToken), // Use access token as unique ID
      userId: Value(user.id),
      accessToken: Value(supabaseSession.accessToken),
      refreshToken: Value(supabaseSession.refreshToken ?? ''),
      email: Value(user.email ?? ''),
      role: Value(user.userMetadata?['role'] as String?),
      userMetadata: Value(userMetadata),
      expiresAt: Value(
        DateTime.fromMillisecondsSinceEpoch(supabaseSession.expiresAt! * 1000),
      ),
      updatedAt: Value(DateTime.now()),
    );

    await _database
        .into(_database.userSessions)
        .insertOnConflictUpdate(sessionData);
  }

  /// Update existing session
  Future<void> updateSession(Session supabaseSession, User user) async {
    final userMetadata = user.userMetadata != null
        ? jsonEncode(user.userMetadata)
        : null;

    final update = UserSessionsCompanion(
      userId: Value(user.id),
      accessToken: Value(supabaseSession.accessToken),
      refreshToken: Value(supabaseSession.refreshToken ?? ''),
      email: Value(user.email ?? ''),
      role: Value(user.userMetadata?['role'] as String?),
      userMetadata: Value(userMetadata),
      expiresAt: Value(
        DateTime.fromMillisecondsSinceEpoch(supabaseSession.expiresAt! * 1000),
      ),
      updatedAt: Value(DateTime.now()),
    );

    await (_database.update(
      _database.userSessions,
    )..where((t) => t.id.equals(supabaseSession.accessToken))).write(update);
  }

  /// Delete session by ID
  Future<void> deleteSession(String sessionId) async {
    await (_database.delete(
      _database.userSessions,
    )..where((t) => t.id.equals(sessionId))).go();
  }

  /// Delete all sessions (logout)
  Future<void> deleteAllSessions() async {
    await _database.delete(_database.userSessions).go();
  }

  /// Get user role from local session
  Future<String?> getUserRole() async {
    final session = await getCurrentSession();
    return session?.role;
  }

  /// Get user metadata from local session
  Future<Map<String, dynamic>?> getUserMetadata() async {
    final session = await getCurrentSession();
    if (session?.userMetadata != null) {
      try {
        return jsonDecode(session!.userMetadata!) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Check if there's a valid local session
  Future<bool> hasValidSession() async {
    final session = await getCurrentSession();
    return session != null;
  }

  /// Get all sessions (for debugging)
  Future<List<UserSession>> getAllSessions() async {
    return await _database.select(_database.userSessions).get();
  }

  /// Clean expired sessions
  Future<void> cleanExpiredSessions() async {
    await (_database.delete(
      _database.userSessions,
    )..where((t) => t.expiresAt.isSmallerThanValue(DateTime.now()))).go();
  }
}

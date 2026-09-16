import 'package:flutter/foundation.dart';

/// Matches the `app_role` enum in the database (IMPLEMENTATION_PLAN §11.1).
enum UserRole {
  owner('Owner'),
  staff('Staff'),
  agent('Agent'),
  member('Member');

  const UserRole(this.label);
  final String label;

  bool get isAdmin => this == owner || this == staff;

  static UserRole? fromName(String? value) {
    final name = value?.toLowerCase();
    for (final role in values) {
      if (role.name == name) return role;
    }
    return null;
  }
}

/// The signed-in user and what they may open.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = UserRole.owner,
    this.agentId,
    this.memberId,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// Set for [UserRole.agent]: their record in `agents`.
  final String? agentId;

  /// Set for [UserRole.member]: their record in `members`.
  final String? memberId;

  bool get isAdmin => role.isAdmin;
  bool get isOwner => role == UserRole.owner;

  /// Demo mode (no Supabase configuration).
  static const guest = AppUser(
    id: 'local-admin',
    name: 'RUDRANSHCT-ADMIN',
    email: 'rudranshct@gmail.com',
  );
}

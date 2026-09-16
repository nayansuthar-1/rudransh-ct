import 'package:flutter/foundation.dart';

@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'ADMIN',
  });

  final String id;
  final String name;
  final String email;
  final String role;

  static const guest = AdminUser(
    id: 'local-admin',
    name: 'RUDRANSHCT-ADMIN',
    email: 'rudranshct@gmail.com',
  );

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'email': email, 'role': role};

  factory AdminUser.fromMap(Map<String, dynamic> map) => AdminUser(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        role: map['role'] as String? ?? 'ADMIN',
      );
}

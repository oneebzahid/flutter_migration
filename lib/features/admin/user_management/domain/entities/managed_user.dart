import 'package:equatable/equatable.dart';

enum UserStatus { pending, approved, rejected }

/// A user record as shown on the User Management screen
/// (React: `UserData` in userService.ts, role 'user' only).
class ManagedUser extends Equatable {
  const ManagedUser({
    required this.uid,
    required this.email,
    required this.status,
    this.fullName,
    this.branch = '',
    this.permissions = const [],
    this.createdAt,
  });

  final String uid;
  final String email;
  final String? fullName;
  final String branch;
  final List<String> permissions;
  final UserStatus status;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
    uid,
    email,
    fullName,
    branch,
    permissions,
    status,
    createdAt,
  ];
}

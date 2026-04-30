import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, estoquista, voluntario, consulta }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  bool get canEdit =>
      role == UserRole.admin ||
      role == UserRole.estoquista ||
      role == UserRole.voluntario;

  bool get canManageUsers => role == UserRole.admin;

  bool get canApproveAdjustments => role == UserRole.admin;

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    final createdRaw = map['createdAt'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : createdRaw is Timestamp
            ? createdRaw.toDate()
            : DateTime.now();

    return AppUser(
      id: id,
      name: map['name'] as String,
      email: map['email'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.consulta,
      ),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role.name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  AppUser copyWith({
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

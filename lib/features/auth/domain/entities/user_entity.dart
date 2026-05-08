enum UserRole {
  chief,
  superAdmin,
  member,
  pending,
}

class UserEntity {
  final String id;
  final String? email;
  final String? phone;
  final String? fullName;
  final String? username;
  final String? avatarUrl;
  final UserRole role;
  final String? circleId;

  const UserEntity({
    required this.id,
    this.email,
    this.phone,
    this.fullName,
    this.username,
    this.avatarUrl,
    required this.role,
    this.circleId,
  });

  factory UserEntity.fromMap(Map<String, dynamic> map) {
    // Parse role string to enum
    final roleString = map['role']?.toString().toLowerCase();
    UserRole parsedRole = UserRole.pending;
    if (roleString == 'chief') parsedRole = UserRole.chief;
    if (roleString == 'superadmin') parsedRole = UserRole.superAdmin;
    if (roleString == 'member') parsedRole = UserRole.member;

    return UserEntity(
      id: map['id'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      fullName: map['full_name'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: parsedRole,
      circleId: map['circle_id'] as String?,
    );
  }
}

class UserRole {
  const UserRole({
    required this.key,
    required this.rank,
    required this.scopeStore,
  });

  final String key;
  final int rank;
  final int? scopeStore;

  factory UserRole.fromJson(Map<String, dynamic> j) => UserRole(
        key: j['key'] as String,
        rank: (j['rank'] as num).toInt(),
        scopeStore: j['scopeStore'] as int?,
      );

  String get displayName {
    return switch (key) {
      'store_manager' => 'Store Manager',
      'line_manager' => 'Line Manager',
      'supervisor' => 'Supervisor',
      'team_member' => 'Team Member',
      _ => key.replaceAll('_', ' '),
    };
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
  });

  final int id;
  final String email;
  final String fullName;
  final List<UserRole> roles;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: (j['id'] as num).toInt(),
        email: j['email'] as String,
        fullName: j['full_name'] as String,
        roles: (j['roles'] as List)
            .map((r) => UserRole.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  UserRole? get primaryRole =>
      roles.isEmpty ? null : roles.reduce((a, b) => a.rank > b.rank ? a : b);
}

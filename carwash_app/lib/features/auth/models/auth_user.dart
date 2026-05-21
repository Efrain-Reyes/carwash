class AuthUser {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final List<String> permissions;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['user']['id'],
      name: json['user']['name'],
      email: json['user']['email'],
      roles: List<String>.from(json['roles']),
      permissions: List<String>.from(json['permissions']),
    );
  }

  bool get isAdmin => roles.contains('administrador');
  bool get isOperator => roles.contains('operador') && !isAdmin;
  bool hasPermission(String permission) => permissions.contains(permission);
}

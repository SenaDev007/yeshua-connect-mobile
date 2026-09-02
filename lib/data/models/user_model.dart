/// Modèle utilisateur (session + participants + résultats de recherche).
library;

class UserModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? role;

  const UserModel({required this.id, required this.name, this.avatarUrl, this.role});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Membre',
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'role': role,
      };
}

/// Session NextAuth renvoyée par `GET /api/auth/session`.
class SessionUser {
  final String id;
  final String name;
  final String email;
  final String? image;
  final String? role;

  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    this.image,
    this.role,
  });

  /// `{}` quand non connecté, sinon `{ user: { id, name, email, role, image } }`.
  factory SessionUser.fromSessionJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user == null || user is! Map) {
      throw const FormatException('session vide');
    }
    return SessionUser(
      id: user['id'] as String? ?? '',
      name: user['name'] as String? ?? 'Membre',
      email: user['email'] as String? ?? '',
      image: user['image'] as String?,
      role: user['role'] as String?,
    );
  }
}

/// ⭐ V1.5 — Blocage des membres (parité web V3.5).
///
/// Une ligne UserBlock = « moi → membre bloqué ». Effets (tous côté
/// serveur, vérifiés à CHAQUE requête) : DM refusé, message privé refusé,
/// appel privé refusé. Les canaux/groupe communs restent OUVERTS — on
/// bloque la personne, pas la communauté (comme Telegram).
library;

/// Membre que J'AI bloqué (réponse de `GET /api/yeshua-connect/blocks`).
class MembreBloqueModel {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime blockedAt;

  const MembreBloqueModel({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.blockedAt,
  });

  factory MembreBloqueModel.fromJson(Map<String, dynamic> json) {
    return MembreBloqueModel(
      userId: json['userId'] as String,
      name: (json['name'] as String?) ?? 'Membre',
      avatarUrl: json['avatarUrl'] as String?,
      blockedAt: DateTime.tryParse(json['blockedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

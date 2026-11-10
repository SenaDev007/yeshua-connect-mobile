/// ⭐ V1.5 — Annonces + messages programmés (modèles, parité web).
library;

/// Annonce publiée dans un canal ANNOUNCEMENT
/// (réponse de `GET /api/yeshua-connect/announcements`).
class AnnonceModel {
  final String id;
  final String authorName;
  final String? authorRole;
  final String title;
  final String body;
  final String priority;
  final DateTime publishedAt;
  final String channelId;
  final String channelName;

  const AnnonceModel({
    required this.id,
    required this.authorName,
    this.authorRole,
    required this.title,
    required this.body,
    required this.priority,
    required this.publishedAt,
    required this.channelId,
    required this.channelName,
  });

  factory AnnonceModel.fromJson(Map<String, dynamic> json) {
    return AnnonceModel(
      id: json['id'] as String,
      authorName: (json['authorName'] as String?) ?? 'Membre',
      authorRole: json['authorRole'] as String?,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      priority: (json['priority'] as String?) ?? 'NORMAL',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
              DateTime.now(),
      channelId: (json['channelId'] as String?) ?? '',
      channelName: (json['channelName'] as String?) ?? '',
    );
  }
}

/// Canal de la communauté (réponse de `GET /api/yeshua-connect/channels`)
/// — utilisé pour le sélecteur de canal lors de la publication d'annonces.
class CanalModel {
  final String id;
  final String name;
  final String type; // TEXT | ANNOUNCEMENT | VOICE | …

  const CanalModel({
    required this.id,
    required this.name,
    required this.type,
  });

  bool get estAnnonce => type == 'ANNOUNCEMENT';

  factory CanalModel.fromJson(Map<String, dynamic> json) {
    return CanalModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'TEXT',
    );
  }
}

// ⭐ V4.21 — MessageProgrammeModel SUPPRIMÉ : la messagerie programmée a
// été retirée de la plateforme (réveil permanent de la base Neon — chaque
// consultation de messagerie scannait la table ScheduledMessage ;
// facture 158 $/3 mois). Voir V4.21 côté web.

/// Modèle d'une conversation — miroir exact de
/// `GET /api/yeshua-connect/conversations` (V3.20).
library;

class ParticipantModel {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? role;      // rôle dans le canal
  final String? userRole;  // ⭐ V3.13 — rôle GLOBAL (badge « Admin »)
  final bool online;

  const ParticipantModel({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.role,
    this.userRole,
    this.online = false,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) => ParticipantModel(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Membre',
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String?,
        userRole: json['userRole'] as String?,
        online: json['online'] as bool? ?? false,
      );
}

class ConversationModel {
  final String id;
  final String type;          // CHANNEL | GROUP | DIRECT | PASTORS | VOICE
  final String name;
  final String? description;
  final String? avatarUrl;

  /// ⭐ V3.20 — Privé 1-1 : confidentiel, réservé à ses 2 membres
  /// (filtrage SERVEUR — l'app n'a rien à masquer, elle ne le reçoit pas).
  final bool isDirect;
  final bool isRestricted;

  final bool videoMode;
  final String createdBy;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final int unreadCount;
  final List<ParticipantModel> participants;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.avatarUrl,
    this.isDirect = false,
    this.isRestricted = false,
    this.videoMode = false,
    this.createdBy = '',
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.participants = const [],
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      ConversationModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'CHANNEL',
        name: json['name'] as String? ?? 'Conversation',
        description: json['description'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        isDirect: json['isDirect'] as bool? ?? false,
        isRestricted: json['isRestricted'] as bool? ?? false,
        videoMode: json['videoMode'] as bool? ?? false,
        createdBy: json['createdBy'] as String? ?? '',
        lastMessageAt: json['lastMessageAt'] == null
            ? null
            : DateTime.parse(json['lastMessageAt'] as String),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        lastMessageSenderId: json['lastMessageSenderId'] as String?,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        participants: (json['participants'] as List<dynamic>? ?? [])
            .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
      );

  ConversationModel copyWith({int? unreadCount}) => ConversationModel(
        id: id,
        type: type,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        isDirect: isDirect,
        isRestricted: isRestricted,
        videoMode: videoMode,
        createdBy: createdBy,
        lastMessageAt: lastMessageAt,
        lastMessagePreview: lastMessagePreview,
        lastMessageSenderId: lastMessageSenderId,
        unreadCount: unreadCount ?? this.unreadCount,
        participants: participants,
        updatedAt: updatedAt,
      );

  /// Pour un PRIVÉ, le titre affiché est le nom de L'AUTRE membre
  /// (le nom du canal est celui du destinataire vu par le créateur).
  /// ⭐ Même logique que le correctif web V3.20.
  String get displayName => isDirect ? otherParticipant?.name ?? name : name;

  /// L'autre participant d'un privé (2 membres) relativement à [meId].
  ParticipantModel? otherOf(String meId) {
    if (!isDirect) return null;
    try {
      return participants.firstWhere((p) => p.userId != meId);
    } catch (_) {
      return null;
    }
  }

  ParticipantModel? get otherParticipant {
    if (participants.length != 2) return null;
    return participants.first;
  }

  /// Nombre de membres en ligne (hors soi-même) — « N en ligne ».
  int enLigneHors(String meId) =>
      participants.where((p) => p.online && p.userId != meId).length;

  bool isLastFromMe(String meId) => lastMessageSenderId == meId;
}

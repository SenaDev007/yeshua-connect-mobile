/// Modèle d'un message de chat — miroir de
/// `GET/POST /api/yeshua-connect/conversations/{id}/messages`.
library;

class ReactionGroup {
  final String emoji;
  final int count;
  final List<String> userIds;

  const ReactionGroup({required this.emoji, required this.count, required this.userIds});

  factory ReactionGroup.fromJson(Map<String, dynamic> json) => ReactionGroup(
        emoji: json['emoji'] as String? ?? '👍',
        count: (json['count'] as num?)?.toInt() ?? 0,
        userIds: (json['userIds'] as List<dynamic>? ?? [])
            .map((u) => u as String)
            .toList(),
      );
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String? senderRole;
  final String type;      // TEXT | VERSE | CALL_LOG | VOICE | POLL…
  final String content;
  final String? verseRef;
  final String? verseText;
  final List<ReactionGroup> reactions;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToContent;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.senderRole,
    required this.type,
    required this.content,
    this.verseRef,
    this.verseText,
    this.reactions = const [],
    this.isPinned = false,
    required this.createdAt,
    this.editedAt,
    this.replyToId,
    this.replyToSenderName,
    this.replyToContent,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final reply = json['replyTo'] as Map<String, dynamic>?;
    return MessageModel(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Membre',
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      senderRole: json['senderRole'] as String?,
      type: json['type'] as String? ?? 'TEXT',
      content: json['content'] as String? ?? '',
      verseRef: json['verseRef'] as String?,
      verseText: json['verseText'] as String?,
      reactions: (json['reactions'] as List<dynamic>? ?? [])
          .map((r) => ReactionGroup.fromJson(r as Map<String, dynamic>))
          .toList(),
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      editedAt: json['editedAt'] == null ? null : DateTime.parse(json['editedAt'] as String),
      replyToId: json['replyToId'] as String?,
      replyToSenderName: reply?['senderName'] as String?,
      replyToContent: reply?['content'] as String?,
    );
  }

  bool get isCallLog => type == 'CALL_LOG';
  bool get isVerse => type == 'VERSE';

  /// Rappel de réponse affiché au-dessus de la bulle.
  bool get hasReply => replyToId != null && (replyToContent?.isNotEmpty ?? false);
}

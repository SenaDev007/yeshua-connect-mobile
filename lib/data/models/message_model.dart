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

  Map<String, dynamic> toJson() => {'emoji': emoji, 'count': count, 'userIds': userIds};
}

/// Sondage attaché à un message type POLL (miroir de /polls).
class PollOptionModel {
  final String id;
  final String label;
  final int order;
  final List<String> voterIds;

  const PollOptionModel({required this.id, required this.label, this.order = 0, this.voterIds = const []});

  factory PollOptionModel.fromJson(Map<String, dynamic> json) => PollOptionModel(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        voterIds: (json['votes'] as List<dynamic>? ?? [])
            .map((v) => (v as Map<String, dynamic>)['userId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList(),
      );
}

class PollModel {
  final String id;
  final String question;
  final bool isMulti;
  final DateTime? expiresAt;
  final List<PollOptionModel> options;

  const PollModel({required this.id, required this.question, this.isMulti = false, this.expiresAt, this.options = const []});

  factory PollModel.fromJson(Map<String, dynamic> json) => PollModel(
        id: json['id'] as String? ?? '',
        question: json['question'] as String? ?? '',
        isMulti: json['isMulti'] as bool? ?? false,
        expiresAt: json['expiresAt'] == null ? null : DateTime.tryParse(json['expiresAt'] as String),
        options: (json['options'] as List<dynamic>? ?? [])
            .map((o) => PollOptionModel.fromJson(o as Map<String, dynamic>))
            .toList(),
      );

  int get totalVotes => options.fold(0, (sum, o) => sum + o.voterIds.length);
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

  // ⭐ V3.21 — Pièces jointes (image/vidéo/fichier) + note vocale.
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentMime;

  /// Durée d'une note vocale (secondes) — messages VOICE.
  final int? voiceDuration;

  /// Sondage attaché — messages POLL.
  final PollModel? poll;

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
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentMime,
    this.voiceDuration,
    this.poll,
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
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentSize: (json['attachmentSize'] as num?)?.toInt(),
      attachmentMime: json['attachmentMime'] as String?,
      voiceDuration: (json['duration'] as num?)?.toInt(),
      poll: json['poll'] == null
          ? null
          : PollModel.fromJson(json['poll'] as Map<String, dynamic>),
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

  /// ⭐ V3.21 — Natures de pièce jointe (mêmes règles que le web).
  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => hasAttachment && (attachmentMime?.startsWith('image/') ?? false);
  bool get isVideo => hasAttachment && (attachmentMime?.startsWith('video/') ?? false);
  bool get isVoiceNote => type == 'AUDIO' || type == 'VOICE';
  bool get isPoll => type == 'POLL' && poll != null;
  bool get isAnnouncement => type == 'ANNOUNCEMENT';

  /// Libellé lisible de la taille (ex. « 1,4 Mo »).
  String get tailleLisible {
    final o = attachmentSize ?? 0;
    if (o < 1024) return '$o o';
    if (o < 1024 * 1024) return '${(o / 1024).toStringAsFixed(0)} Ko';
    return '${(o / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Mise à jour locale après modification/épinglage/réaction (polling court).
  MessageModel copyWith({
    String? content,
    DateTime? editedAt,
    bool? isPinned,
    List<ReactionGroup>? reactions,
  }) =>
      MessageModel(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        senderRole: senderRole,
        type: type,
        content: content ?? this.content,
        verseRef: verseRef,
        verseText: verseText,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentSize: attachmentSize,
        attachmentMime: attachmentMime,
        voiceDuration: voiceDuration,
        poll: poll,
        reactions: reactions ?? this.reactions,
        isPinned: isPinned ?? this.isPinned,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        replyToId: replyToId,
        replyToSenderName: replyToSenderName,
        replyToContent: replyToContent,
      );
}

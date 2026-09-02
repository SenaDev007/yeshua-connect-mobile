/// Modèles d'appel — miroir de `GET /api/yeshua-connect/calls/signal`
/// (V3.1 signalisation + ⭐ V3.20 isDirect / initiatorName).
library;

/// Appel entrant renvoyé par `?incoming=1`.
class IncomingCallModel {
  final String callId;
  final String conversationId;

  /// Nom du canal (⚠️ sur un PRIVÉ, c'est le nom du DESTINATAIRE choisi
  /// par le créateur — V1.0 affichait convName partout, d'où le bug
  /// « Ora voyait son propre nom quand Pam l'appelait »).
  final String convName;
  final String? convAvatarUrl;
  final String convType;

  /// ⭐ V3.20 — true sur un privé 1-1.
  final bool isDirect;

  /// ⭐ V3.20 — nom de L'APPELANT : LA source du correctif V1.1.
  final String initiatorId;
  final String initiatorName;
  final String? initiatorAvatarUrl;

  final String callType; // audio | video
  final DateTime createdAt;

  const IncomingCallModel({
    required this.callId,
    required this.conversationId,
    required this.convName,
    this.convAvatarUrl,
    this.convType = 'CHANNEL',
    this.isDirect = false,
    required this.initiatorId,
    required this.initiatorName,
    this.initiatorAvatarUrl,
    this.callType = 'audio',
    required this.createdAt,
  });

  factory IncomingCallModel.fromJson(Map<String, dynamic> json) => IncomingCallModel(
        callId: json['callId'] as String? ?? '',
        conversationId: json['conversationId'] as String? ?? '',
        convName: json['convName'] as String? ?? 'Conversation',
        convAvatarUrl: json['convAvatarUrl'] as String?,
        convType: json['convType'] as String? ?? 'CHANNEL',
        isDirect: json['isDirect'] as bool? ?? false,
        initiatorId: json['initiatorId'] as String? ?? '',
        initiatorName: json['initiatorName'] as String? ?? 'Membre',
        initiatorAvatarUrl: json['initiatorAvatarUrl'] as String?,
        callType: json['callType'] as String? ?? 'audio',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  /// ⭐⭐ V1.1 — CORRECTIF DU NOM DE L'APPELANT ⭐⭐
  ///
  /// Sur un appel entrant PRIVÉ (`isDirect`), l'écran doit titrer
  /// **L'APPELANT** (`initiatorName`) — pas le nom du canal, qui est
  /// celui du destinataire (d'où « Ora voit son propre nom » en V1.0).
  /// Sur un canal/groupe, le nom du canal reste affiché.
  String get displayTitle => isDirect ? initiatorName : convName;

  /// Photo prioritaire : celle de l'appelant sur un privé, celle du canal sinon.
  String? get displayAvatar => isDirect ? (initiatorAvatarUrl ?? convAvatarUrl) : convAvatarUrl;

  /// Sous-ligne : l'appelant en petit sur un appel de canal/groupe.
  String? get displaySubtitle => isDirect ? null : 'Appel de $initiatorName';

  bool get isVideo => callType == 'video';
}

/// Statut d'un appel (polling `?callId=`).
class CallStatusModel {
  final String status;   // ringing | accepted | declined | missed | cancelled | ended
  final int? duration;
  final String type;

  /// ⭐ V3.21 — Fournisseur multimédia ARBITRÉ de l'appel (renvoyé par le
  /// polling de statut) : bascule à chaud — si l'autre partie a signalé
  /// l'échec de LiveKit, le serveur a fait avancer l'appel à Agora/Daily
  /// et NOTRE média bascule sans raccrocher.
  final String? mediaProvider;

  const CallStatusModel({required this.status, this.duration, this.type = 'audio', this.mediaProvider});

  factory CallStatusModel.fromJson(Map<String, dynamic> json) => CallStatusModel(
        status: json['status'] as String? ?? 'ringing',
        duration: (json['duration'] as num?)?.toInt(),
        type: json['type'] as String? ?? 'audio',
        mediaProvider: json['mediaProvider'] as String?,
      );

  bool get isTerminal =>
      status == 'declined' || status == 'missed' || status == 'cancelled' || status == 'ended';
}

/// Réponse de `POST { action: "start" }`.
class StartedCallModel {
  final String callId;
  final String? conversationName;
  final String? conversationAvatarUrl;
  final String? conversationType;

  const StartedCallModel({
    required this.callId,
    this.conversationName,
    this.conversationAvatarUrl,
    this.conversationType,
  });

  factory StartedCallModel.fromJson(Map<String, dynamic> json) {
    final conv = json['conversation'] as Map<String, dynamic>?;
    return StartedCallModel(
      callId: json['callId'] as String? ?? '',
      conversationName: conv?['name'] as String?,
      conversationAvatarUrl: conv?['avatarUrl'] as String?,
      conversationType: conv?['type'] as String?,
    );
  }
}

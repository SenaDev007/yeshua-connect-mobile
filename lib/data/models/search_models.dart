/// Modèles de la recherche globale — miroir de
/// `GET /api/yeshua-connect/search?q=…`.
library;

class SearchMessageResult {
  final String id;
  final String content;
  final DateTime createdAt;
  final String senderName;
  final String channelId;
  final String channelName;

  const SearchMessageResult({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.senderName,
    required this.channelId,
    required this.channelName,
  });

  factory SearchMessageResult.fromJson(Map<String, dynamic> json) =>
      SearchMessageResult(
        id: json['id'] as String? ?? '',
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        senderName: json['senderName'] as String? ?? 'Membre',
        channelId: json['channelId'] as String? ?? '',
        channelName: json['channelName'] as String? ?? '',
      );
}

class SearchChannelResult {
  final String id;
  final String name;
  final String type;

  const SearchChannelResult({required this.id, required this.name, required this.type});

  factory SearchChannelResult.fromJson(Map<String, dynamic> json) => SearchChannelResult(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'CHANNEL',
      );
}

class SearchUserResult {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? role;

  const SearchUserResult({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role,
  });

  factory SearchUserResult.fromJson(Map<String, dynamic> json) => SearchUserResult(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Membre',
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String?,
      );
}

class SearchResults {
  final List<SearchMessageResult> messages;
  final List<SearchChannelResult> channels;
  final List<SearchUserResult> users;

  const SearchResults({
    this.messages = const [],
    this.channels = const [],
    this.users = const [],
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((m) => SearchMessageResult.fromJson(m as Map<String, dynamic>))
            .toList(),
        channels: (json['channels'] as List<dynamic>? ?? [])
            .map((c) => SearchChannelResult.fromJson(c as Map<String, dynamic>))
            .toList(),
        users: (json['users'] as List<dynamic>? ?? [])
            .map((u) => SearchUserResult.fromJson(u as Map<String, dynamic>))
            .toList(),
      );

  bool get isEmpty => messages.isEmpty && channels.isEmpty && users.isEmpty;
}

/// Membre d'une conversation — miroir de
/// `GET /api/yeshua-connect/conversations/{id}/members`.
class MemberModel {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String role;      // rôle dans le canal
  final String? userRole; // rôle GLOBAL (badge)
  final bool isOnline;
  final DateTime joinedAt;

  const MemberModel({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.role = 'MEMBER',
    this.userRole,
    this.isOnline = false,
    required this.joinedAt,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) => MemberModel(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Membre',
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String? ?? 'MEMBER',
        userRole: json['userRole'] as String?,
        isOnline: json['isOnline'] as bool? ?? json['online'] as bool? ?? false,
        joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Fiche membre — miroir de `GET /api/yeshua-connect/members/{userId}/profile`.
class MemberProfileModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? role;
  final String? bio;
  final String? country;
  final String? city;
  final DateTime? lastSeenAt;
  final DateTime? memberSince;

  const MemberProfileModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role,
    this.bio,
    this.country,
    this.city,
    this.lastSeenAt,
    this.memberSince,
  });

  factory MemberProfileModel.fromJson(Map<String, dynamic> json) => MemberProfileModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Membre',
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String?,
        bio: json['bio'] as String?,
        country: json['country'] as String?,
        city: json['city'] as String?,
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.tryParse(json['lastSeenAt'] as String),
        memberSince: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );

  bool get isOnline =>
      lastSeenAt != null &&
      DateTime.now().difference(lastSeenAt!).inSeconds < 90; // même fenêtre que le serveur
}

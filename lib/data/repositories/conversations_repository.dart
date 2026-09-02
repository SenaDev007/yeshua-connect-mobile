/// Conversations : liste (V3.20 filtrage serveur des privés), membres,
/// démarrage d'un privé, marquage lu.
library;

import '../api/api_client.dart';
import '../models/conversation_model.dart';
import '../models/search_models.dart';
class ConversationsRepository {
  final ApiClient _api = ApiClient.instance;

  ConversationsRepository();

  /// Liste des conversations visibles — le serveur n'envoie déjà plus les
  /// privés des autres (V3.20) : rien à filtrer côté mobile.
  Future<List<ConversationModel>> liste() async {
    final data = await _api.getJson('/api/yeshua-connect/conversations');
    final list = data is List ? data : const <dynamic>[];
    return list
        .map((c) => ConversationModel.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
  }

  /// Membres d'une conversation (avec présence réelle).
  Future<List<MemberModel>> membres(String conversationId) async {
    final data = await _api.getJson('/api/yeshua-connect/conversations/$conversationId/members');
    final list = data is List ? data : const <dynamic>[];
    return list
        .map((m) => MemberModel.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Retrouve (ou crée) un privé avec [targetUserId] — anti-spam serveur :
  /// il faut partager un canal commun.
  Future<String> demarrerPrive(String targetUserId) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/conversations/dm',
      body: {'targetUserId': targetUserId},
    );
    if (data is Map && data['conversationId'] is String) {
      return data['conversationId'] as String;
    }
    throw const ApiException('Impossible d\'ouvrir la conversation privée.');
  }

  /// Marque la conversation comme lue (reset unreadCount).
  Future<void> marquerLu(String conversationId) async {
    await _api.postJson('/api/yeshua-connect/conversations/$conversationId/read');
  }

  /// Fiche d'un membre.
  Future<MemberProfileModel> profil(String userId) async {
    final data = await _api.getJson('/api/yeshua-connect/members/$userId/profile');
    if (data is Map) {
      return MemberProfileModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Membre introuvable.');
  }
}

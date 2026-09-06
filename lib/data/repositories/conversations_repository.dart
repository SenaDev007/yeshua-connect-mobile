/// Conversations : liste (V3.20 filtrage serveur des privés), membres,
/// démarrage d'un privé, marquage lu.
/// ⭐ V1.8 — HORS-LIGNE : la liste est mise en cache à chaque succès réseau
/// et servie depuis le cache quand le serveur est injoignable (l'app reste
/// lisible sans internet — exigence pasteur).
library;

import '../../core/offline/cache_local.dart';
import '../api/api_client.dart';
import '../models/conversation_model.dart';
import '../models/search_models.dart';
class ConversationsRepository {
  final ApiClient _api = ApiClient.instance;

  ConversationsRepository();

  /// Liste des conversations visibles — le serveur n'envoie déjà plus les
  /// privés des autres (V3.20) : rien à filtrer côté mobile.
  ///
  /// ⭐ V1.7 — DÉDOUBLONNAGE par identifiant : l'API peut renvoyer deux
  /// entrées pour un même canal (ex. refresh pendant une création) —
  /// la liste plate les affichait en double (« conversations multipliées »).
  ///
  /// ⭐ V1.8 — repli hors-ligne : réseau OK → cache mis à jour ; réseau KO
  /// → dernière liste enregistrée servie telle quelle.
  Future<List<ConversationModel>> liste() async {
    final data = await CacheLocal.instance.getAvecCache(
      CacheLocal.cleConversations,
      () => _api.getJson('/api/yeshua-connect/conversations'),
    );
    return _parseListe(data);
  }

  /// Analyse (et dédoublonne) une réponse réseau OU cache.
  List<ConversationModel> _parseListe(dynamic data) {
    final list = data is List ? data : const <dynamic>[];
    final vues = <String>{};
    final conversations = <ConversationModel>[];
    for (final c in list) {
      if (c is! Map) continue;
      final conv = ConversationModel.fromJson(
          Map<String, dynamic>.from(c));
      if (conv.id.isEmpty || !vues.add(conv.id)) continue; // doublon écarté
      conversations.add(conv);
    }
    // Tri stable : activité la plus récente en tête (cohérent avec le web).
    conversations.sort((a, b) => (b.lastMessageAt ?? b.updatedAt)
        .compareTo(a.lastMessageAt ?? a.updatedAt));
    return conversations;
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

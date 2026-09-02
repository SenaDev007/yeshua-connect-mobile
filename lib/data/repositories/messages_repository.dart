/// Messages : lecture paginée (cursor `before`) + envoi.
library;

import '../api/api_client.dart';
import '../models/message_model.dart';
class MessagesRepository {
  final ApiClient _api = ApiClient.instance;

  MessagesRepository();

  /// Les [limit] messages les plus récents (ordre ancien → récent).
  /// Avec [before], charge les messages plus ANCIENS que ce message-cursor
  /// (« charger plus ancien » au scroll vers le haut).
  Future<List<MessageModel>> messages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final data = await _api.getJson(
      '/api/yeshua-connect/conversations/$conversationId/messages',
      queryParameters: query,
    );
    final list = data is List ? data : const <dynamic>[];
    return list
        .map((m) => MessageModel.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Envoie un message — `userId` vient de la session serveur.
  Future<MessageModel> envoyer(String conversationId, String content) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/conversations/$conversationId/messages',
      body: {'content': content, 'type': 'TEXT'},
    );
    if (data is Map) {
      return MessageModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException("Échec de l'envoi du message.");
  }
}

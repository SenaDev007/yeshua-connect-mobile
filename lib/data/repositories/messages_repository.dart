/// Messages : lecture paginée (cursor `before`) + envoi + ⭐ V3.21
/// interactions COMPLÈTES (répondre, réagir, épingler, modifier, supprimer,
/// transférer, pièces jointes, notes vocales, votes de sondage) — miroir
/// exact des routes web `/messages/*`.
library;

import 'package:dio/dio.dart';

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
  /// [replyToId] : réponse à un message (rappel affiché au-dessus de la bulle).
  Future<MessageModel> envoyer(
    String conversationId,
    String content, {
    String? replyToId,
  }) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/conversations/$conversationId/messages',
      body: {
        'content': content,
        'type': 'TEXT',
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    if (data is Map) {
      return MessageModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException("Échec de l'envoi du message.");
  }

  /// ⭐ Partage d'un verset — même format que le web (V2.6) :
  /// `type: "VERSE"`, `content` = référence, `verseRef`/`verseText`.
  Future<MessageModel> envoyerVerset(
    String conversationId,
    String reference,
    String texte,
  ) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/conversations/$conversationId/messages',
      body: {
        'content': reference,
        'type': 'VERSE',
        'verseRef': reference,
        'verseText': texte,
      },
    );
    if (data is Map) {
      return MessageModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException("Échec du partage du verset.");
  }

  // ═══════════════════════════════════════════════════════════════════
  // ⭐ V3.21 — INTERACTIONS DE PARITÉ WEB (routes /messages/{id}/…)
  // ═══════════════════════════════════════════════════════════════════

  /// Réagit (emoji spirituel 🙏 ✋ ❤️ 📖 🔥 ⭐) — toggle côté serveur :
  /// re-cliquer le même emoji RETIRE ma réaction (même comportement web).
  Future<void> reagir(String messageId, String emoji) async {
    await _api.postJson(
      '/api/yeshua-connect/messages/$messageId/react',
      body: {'emoji': emoji},
    );
  }

  /// Épingle / désépingle un message (toggle persisté en base — panneau
  /// « Messages épinglés » du web et pastille dorée dans le fil).
  Future<void> epingler(String messageId) async {
    await _api.postJson(
      '/api/yeshua-connect/messages/$messageId/pin',
      body: {},
    );
  }

  /// Modifie le CONTENU de mon message (badge « modifié » + editedAt).
  Future<void> modifier(String messageId, String contenu) async {
    await _api.putJson(
      '/api/yeshua-connect/messages/$messageId/edit',
      body: {'content': contenu},
    );
  }

  /// Supprime un message — [pourToutLeMonde] : true = pour tous (auteur ou
  /// modérateur, le message disparaît pour tout le monde) ; false = pour moi
  /// uniquement (caché localement, comme le web V2.8).
  Future<void> supprimer(String messageId, {bool pourToutLeMonde = false}) async {
    await _api.deleteJson(
      '/api/yeshua-connect/messages/$messageId/delete',
      queryParameters: {'forEveryone': pourToutLeMonde ? 'true' : 'false'},
    );
  }

  /// Transfère un message vers une autre conversation.
  Future<void> transferer(String messageId, String conversationCibleId) async {
    await _api.postJson(
      '/api/yeshua-connect/messages/$messageId/forward',
      body: {'targetChannelId': conversationCibleId},
    );
  }

  /// Vote à un sondage (option unique ou multiple selon le poll).
  Future<void> voter(String pollId, List<String> optionIds) async {
    await _api.postJson(
      '/api/yeshua-connect/polls/$pollId/vote',
      body: {'optionIds': optionIds},
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ⭐ V3.21 — PIÈCES JOINTES + NOTES VOCALES (upload multipart)
  // ═══════════════════════════════════════════════════════════════════

  /// Envoie une pièce jointe (image/vidéo/fichier) — multipart {file, type},
  /// même route que le web (R2 en production, data-URL en dev).
  /// [cheminFichier] : chemin local du fichier à uploader.
  /// [type] : 'IMAGE' | 'VIDEO' | 'FILE' | 'AUDIO' (défaut FILE).
  Future<MessageModel> envoyerPieceJointe(
    String conversationId,
    String cheminFichier,
    String nomFichier, {
    String type = 'FILE',
    String mimeType = 'application/octet-stream',
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        cheminFichier,
        filename: nomFichier,
        contentType: DioMediaType.parse(mimeType),
      ),
      'type': type,
    });
    final data = await _api.postFormJson(
      '/api/yeshua-connect/conversations/$conversationId/messages/attachment',
      formData,
    );
    if (data is Map) {
      return MessageModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException("Échec de l'envoi de la pièce jointe.");
  }

  /// Envoie une note vocale (enregistrement .m4a/.aac) — type AUDIO +
  /// durée en secondes.
  Future<MessageModel> envoyerNoteVocale(
    String conversationId,
    String cheminFichier, {
    required int dureeSecondes,
  }) async {
    return envoyerPieceJointe(
      conversationId,
      cheminFichier,
      'note_vocale.m4a',
      type: 'AUDIO',
      mimeType: 'audio/mp4',
    ).then((message) {
      // La durée est portée par le message serveur (colonne duration) —
      // le renvoi du message est déjà complet.
      return message;
    });
  }
}

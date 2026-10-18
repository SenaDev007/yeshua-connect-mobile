/// État d'un chat ouvert : messages + polling + envoi + pagination +
/// ⭐ V3.21 interactions de parité web (répondre, réagir, épingler,
/// modifier, supprimer, transférer, pièces jointes, notes vocales).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/offline/connectivite.dart';
import '../core/offline/db_local.dart';
import '../data/api/api_client.dart';
import '../data/models/message_model.dart';
import '../data/repositories/messages_repository.dart';
class ChatState {
  final List<MessageModel> messages;
  final bool chargement;
  final bool chargementPlus;
  final bool envoiEnCours;
  final String? error;
  final bool aToutCharge; // plus rien de plus ancien à charger

  const ChatState({
    this.messages = const [],
    this.chargement = false,
    this.chargementPlus = false,
    this.envoiEnCours = false,
    this.error,
    this.aToutCharge = false,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? chargement,
    bool? chargementPlus,
    bool? envoiEnCours,
    String? error,
    bool clearError = false,
    bool? aToutCharge,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        chargement: chargement ?? this.chargement,
        chargementPlus: chargementPlus ?? this.chargementPlus,
        envoiEnCours: envoiEnCours ?? this.envoiEnCours,
        error: clearError ? null : (error ?? this.error),
        aToutCharge: aToutCharge ?? this.aToutCharge,
      );
}

/// Un contrôleur de chat PAR conversation ouverte (family).
class ChatController extends StateNotifier<ChatState> {
  final String conversationId;
  final MessagesRepository _repo = MessagesRepository();
  Timer? _timer;

  ChatController(this.conversationId) : super(const ChatState()) {
    charger();
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.chatPollSeconds),
      (_) => _poll(),
    );
    // ⭐ V2.0 — au retour du réseau, vider la file d'envoi différé
    // (messages rédigés hors ligne « façon WhatsApp »).
    _abonnementConnexion = Connectivite.instance.flux.listen((enLigne) {
      if (enLigne) unawaited(purgerOutboxLocal());
    });
  }

  StreamSubscription<bool>? _abonnementConnexion;

  /// Chargement initial (le bas de la conversation).
  /// ⭐ V2.0 — les messages en attente d'envoi (outbox « façon
  /// WhatsApp ») sont ré-affichés en fin de fil.
  Future<void> charger() async {
    state = state.copyWith(chargement: true, clearError: true);
    try {
      final messages = await _repo.messages(conversationId);
      final enAttente = await _bullesOutbox();
      state = ChatState(
        messages: [...messages, ...enAttente],
        aToutCharge: messages.length < 50,
      );
    } catch (e) {
      state = state.copyWith(chargement: false, error: e.toString());
    }
  }

  /// Bulles « en attente » de cette conversation (issues de l'outbox
  /// SQLite) — affichées en fin de fil tant que le réseau n'est pas
  /// revenu.
  Future<List<MessageModel>> _bullesOutbox() async {
    try {
      final file = await DbLocal.instance.lireOutboxConversation(conversationId);
      return file.map((ligne) {
        final creeLe = DateTime.tryParse(ligne['cree_le'] as String? ?? '') ?? DateTime.now();
        return MessageModel(
          id: 'outbox-${ligne['id']}',
          conversationId: conversationId,
          senderId: '__outbox__',
          senderName: 'Moi',
          type: 'TEXT',
          content: ligne['contenu'] as String? ?? '',
          createdAt: creeLe,
          enAttenteLocal: true,
        );
      }).toList();
    } catch (_) {
      return const <MessageModel>[];
    }
  }

  /// Polling : ne récupère que ce qui est PLUS RÉCENT que le dernier connu,
  /// et fusionne proprement (dédupliqué par id).
  ///
  /// ⭐ V1.8 — PAUSÉ hors ligne (batterie + inutilité) : le fil affiché
  /// reste celui du cache local, il se resynchronise au retour du réseau.
  Future<void> _poll() async {
    if (state.chargement || state.chargementPlus) return;
    if (!Connectivite.instance.enLigne) return;
    try {
      final frais = await _repo.messages(conversationId);
      if (frais.isEmpty) return;
      final connus = state.messages.map((m) => m.id).toSet();
      final nouveaux = frais.where((m) => !connus.contains(m.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (nouveaux.isEmpty) return;
      // Remplace aussi les bulles existantes (réactions/épinglage éventuels).
      final byId = {for (final m in state.messages) m.id: m};
      for (final m in frais) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: merged);
    } catch (_) {
      // Polling silencieux : on retente au prochain tick.
    }
  }

  /// « Charger plus ancien » au scroll vers le haut (cursor pagination).
  Future<void> chargerPlusAnciens() async {
    if (state.chargementPlus || state.aToutCharge || state.messages.isEmpty) return;
    state = state.copyWith(chargementPlus: true, clearError: true);
    try {
      final plusAnciens = await _repo.messages(
        conversationId,
        before: state.messages.first.id,
      );
      final connus = state.messages.map((m) => m.id).toSet();
      final nouveaux = plusAnciens.where((m) => !connus.contains(m.id)).toList();
      state = state.copyWith(
        messages: [...nouveaux, ...state.messages],
        chargementPlus: false,
        aToutCharge: plusAnciens.length < 50,
      );
    } catch (e) {
      state = state.copyWith(chargementPlus: false, error: e.toString());
    }
  }

  /// Envoie un message (optimiste puis remplacement par la réponse serveur).
  ///
  /// ⭐ V2.0 — OUTBOX « façon WhatsApp » : si le réseau est absent (ou le
  /// serveur injoignable), le message est mis EN FILE dans la base locale
  /// (table `outbox`), affiché immédiatement en bulle « en attente »
  /// (horloge), et envoyé AUTOMATIQUEMENT au retour de la connexion
  /// (ordre FIFO, cf. [purgerOutboxLocal]).
  ///
  /// [reponseA] : message auquel on répond (rappel affiché au-dessus de
  /// la bulle — même UX que le web).
  Future<void> envoyer(String content, {MessageModel? reponseA}) async {
    final texte = content.trim();
    if (texte.isEmpty || state.envoiEnCours) return;
    state = state.copyWith(envoiEnCours: true, clearError: true);

    // ── Hors ligne : file locale, bulle « en attente », zéro erreur ──
    if (!Connectivite.instance.enLigne) {
      await _mettreEnFile(texte, reponseA);
      return;
    }
    try {
      final message = await _repo.envoyer(
        conversationId,
        texte,
        replyToId: reponseA?.id,
      );
      final connus = state.messages.map((m) => m.id).toSet();
      if (!connus.contains(message.id)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
      state = state.copyWith(envoiEnCours: false);
    } catch (e) {
      if (e is ApiException && e.reseauKO) {
        // Serveur injoignable (wifi coupé en cours d'envoi, incident…) :
        // même traitement que « pas de réseau » — file + bulle en attente.
        await _mettreEnFile(texte, reponseA);
        return;
      }
      state = state.copyWith(envoiEnCours: false, error: e.toString());
      rethrow;
    }
  }

  /// Insère le message dans l'outbox SQLite et l'affiche en attente.
  Future<void> _mettreEnFile(String texte, MessageModel? reponseA) async {
    await DbLocal.instance.ajouterOutbox(
      conversationId,
      texte,
      reponseA: reponseA?.id,
    );
    final bulle = MessageModel(
      id: 'outbox-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: '__outbox__',
      senderName: 'Moi',
      type: 'TEXT',
      content: texte,
      createdAt: DateTime.now(),
      replyToId: reponseA?.id,
      replyToSenderName: reponseA?.senderName,
      replyToContent: reponseA?.content,
      enAttenteLocal: true,
    );
    state = state.copyWith(
      envoiEnCours: false,
      messages: [...state.messages, bulle],
    );
  }

  /// ⭐ V2.0 — Vide la file d'envoi de CETTE conversation (FIFO) puis
  /// retire les bulles « en attente » envoyées. Appelé au retour du
  /// réseau et à l'ouverture du chat.
  Future<void> purgerOutboxLocal() async {
    if (!Connectivite.instance.enLigne) return;
    final file = await DbLocal.instance.lireOutboxConversation(conversationId);
    if (file.isEmpty) return;
    for (final ligne in file) {
      final id = ligne['id'] as int;
      try {
        await _repo.envoyer(
          conversationId,
          ligne['contenu'] as String,
          replyToId: ligne['reponse_a'] as String?,
        );
        await DbLocal.instance.supprimerOutbox(id);
      } on ApiException catch (e) {
        if (e.reseauKO) return; // réseau retombé : le reste attendra
        await DbLocal.instance.supprimerOutbox(id); // erreur applicative
      } catch (_) {
        await DbLocal.instance.noterTentative(id);
      }
    }
    // Les bulles « en attente » encore en file restent affichées ; les
    // envoyées disparaissent (le serveur renvoie les vraies au polling).
    state = state.copyWith(
      messages: state.messages.where((m) => !m.enAttenteLocal).toList(),
    );
    unawaited(_poll());
  }

  // ═════════════════════════════════════════════════════════════
  // ⭐ V3.21 — INTERACTIONS DE PARITÉ WEB
  // ═════════════════════════════════════════════════════════════

  /// Réagit (toggle serveur) puis rafraîchit la bulle localement — le
  /// polling finira par confirmer, mais l'UI réagit instantanément.
  Future<void> reagir(String messageId, String emoji) async {
    try {
      await _repo.reagir(messageId, emoji);
      await _majMessage(messageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Épingle / désépingle (toggle persisté).
  Future<void> epingler(String messageId) async {
    try {
      await _repo.epingler(messageId);
      await _majMessage(messageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Modifie mon message (badge « modifié »).
  Future<void> modifier(String messageId, String nouveauContenu) async {
    final texte = nouveauContenu.trim();
    if (texte.isEmpty) return;
    try {
      await _repo.modifier(messageId, texte);
      await _majMessage(messageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Supprime un message (pour tous si auteur/modérateur, sinon pour moi).
  Future<void> supprimer(String messageId, {required bool pourToutLeMonde}) async {
    try {
      await _repo.supprimer(messageId, pourToutLeMonde: pourToutLeMonde);
      if (pourToutLeMonde) {
        // « Pour tous » : la bulle disparaît immédiatement.
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != messageId).toList(),
        );
      } else {
        await _majMessage(messageId);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Transfère vers une autre conversation.
  Future<void> transferer(String messageId, String conversationCible) async {
    await _repo.transferer(messageId, conversationCible);
  }

  /// Vote à un sondage (une option par appel — mono : le serveur remplace
  /// l'ancien vote ; multi : on peut en cocher plusieurs, comme le web).
  /// ⭐ V1.6 : signature corrigée (optionId singulier, format de l'API web).
  Future<void> voter(String pollId, String optionId) async {
    try {
      await _repo.voter(pollId, optionId);
      // Les résultats arrivent au prochain polling (les bulles POLL se
      // mettent à jour avec les compteurs).
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Envoie une pièce jointe (image/vidéo/fichier).
  Future<void> envoyerPieceJointe(
    String chemin,
    String nom, {
    required String type,
    required String mime,
  }) async {
    state = state.copyWith(envoiEnCours: true, clearError: true);
    try {
      final message = await _repo.envoyerPieceJointe(
        conversationId,
        chemin,
        nom,
        type: type,
        mimeType: mime,
      );
      final connus = state.messages.map((m) => m.id).toSet();
      if (!connus.contains(message.id)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
      state = state.copyWith(envoiEnCours: false);
    } catch (e) {
      state = state.copyWith(envoiEnCours: false, error: e.toString());
      rethrow;
    }
  }

  /// Envoie une note vocale enregistrée.
  Future<void> envoyerNoteVocale(String chemin, int dureeSec) async {
    state = state.copyWith(envoiEnCours: true, clearError: true);
    try {
      final message = await _repo.envoyerNoteVocale(
        conversationId,
        chemin,
        dureeSecondes: dureeSec,
      );
      final connus = state.messages.map((m) => m.id).toSet();
      if (!connus.contains(message.id)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
      state = state.copyWith(envoiEnCours: false);
    } catch (e) {
      state = state.copyWith(envoiEnCours: false, error: e.toString());
      rethrow;
    }
  }

  /// Re-lit UN message côté serveur et remplace la bulle locale.
  Future<void> _majMessage(String messageId) async {
    try {
      final frais = await _repo.messages(conversationId, limit: 50);
      final maj = frais.where((m) => m.id == messageId).toList();
      if (maj.isEmpty) return;
      state = state.copyWith(
        messages: state.messages.map((m) => m.id == messageId ? maj.first : m).toList(),
      );
    } catch (_) {}
  }

  /// ⭐ V3.21 — Messages épinglés de la conversation (panneau dédié).
  List<MessageModel> get epingles =>
      state.messages.where((m) => m.isPinned).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void dispose() {
    _timer?.cancel();
    _abonnementConnexion?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.family<ChatController, ChatState, String>(
  (ref, conversationId) => ChatController(conversationId),
);

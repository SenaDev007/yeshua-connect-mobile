/// ⭐ V2.0 — MOTEUR DE SYNCHRONISATION DU CONTENU PUBLIC.
///
/// « Toutes les pages doivent pouvoir s'utiliser hors ligne, avec une
/// base de données locale intégrée ; seules les vidéos exigent la
/// connexion » (exigence du pasteur).
///
/// Fonctionnement :
///   1. AU DÉMARRAGE : le contenu est lu depuis SQLite — l'app est
///      immédiatement utilisable, même sans réseau ;
///   2. EN LIGNE : `GET /api/app/sync` (web V4.12) renvoie TOUT le
///      contenu (serviteurs, héros, témoignages, enseignements, vidéos,
///      vies transformées, annonces, lives, dispersés) → écrit dans
///      SQLite → l'état Riverpod notifie tous les écrans ;
///   3. SURVEILLANCE LÉGÈRE : toutes les 60 s, `GET /api/app/content`
///      (web V4.10 — hash FNV des tampons de mise à jour) ; si le hash
///      a changé (le back-office a publié quelque chose) → resynchroni-
///      sation complète. Le back-office reste l'unique source de vérité :
///      une photo remplacée, une nouvelle vidéo, une annonce… tout est
///      répercuté dans l'app dès qu'elle a du réseau ;
///   4. AU RETOUR DU RÉSEAU : resynchronisation + purge de la file
///      d'envoi des messages rédigés hors ligne (outbox).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/models/contenu_models.dart';
import '../../data/repositories/messages_repository.dart';
import '../core/offline/connectivite.dart';
import '../core/offline/db_local.dart';

class ContenuController extends StateNotifier<ContenuState> {
  ContenuController() : super(const ContenuState()) {
    _demarrer();
  }

  final DbLocal _db = DbLocal.instance;
  Timer? _minuteur;
  StreamSubscription<bool>? _abonnementConnexion;
  bool _enCours = false;

  // ═════════════════════════════════════════════════════════════════
  //  DÉMARRAGE
  // ═════════════════════════════════════════════════════════════════

  Future<void> _demarrer() async {
    // 1) Contenu local d'abord (instantané, sans réseau).
    await chargerDepuisBase();

    // 2) Puis synchronisation si le réseau le permet.
    unawaited(synchroniser());

    // 3) Surveillance légère (hash) toutes les 60 s en ligne.
    _minuteur = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_verifierHash()),
    );

    // 4) Au retour du réseau : resynchroniser + vider l'outbox.
    _abonnementConnexion = Connectivite.instance.flux.listen((enLigne) {
      if (enLigne) {
        unawaited(synchroniser());
        unawaited(purgerOutbox());
      }
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _abonnementConnexion?.cancel();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════
  //  LECTURE LOCALE (SQLite)
  // ═════════════════════════════════════════════════════════════════

  /// Recharge l'état depuis SQLite (appelé au démarrage et après chaque
  /// synchronisation réussie).
  Future<void> chargerDepuisBase() async {
    try {
      final serviteursJson = await _db.lireContenu('serviteurs');
      final heroesJson = await _db.lireContenu('heroes');
      final temoignagesJson = await _db.lireContenu('temoignages');
      final enseignementsJson = await _db.lireContenu('enseignements');
      final videosJson = await _db.lireContenu('videos');
      final viesJson = await _db.lireContenu('viesTransformees');
      final annoncesJson = await _db.lireContenu('annonces');
      final livesJson = await _db.lireContenu('lives');
      final dispersesJson = await _db.lireContenu('disperses');
      final maj = await _db.dateMajContenu('serviteurs');

      final heroes = <String, HeroConfigModele>{};
      if (heroesJson is Map<String, dynamic>) {
        for (final e in heroesJson.entries) {
          if (e.value is Map<String, dynamic>) {
            heroes[e.key] = HeroConfigModele.fromJson(
              e.key,
              e.value as Map<String, dynamic>,
            );
          }
        }
      }

      final livesMap = livesJson is Map<String, dynamic> ? livesJson : <String, dynamic>{};

      // ⭐ V2.4 — membres dispersés positionnés (carte précise).
      final dispersesMembres = dispersesJson is Map<String, dynamic> &&
              dispersesJson['membres'] is List
          ? (dispersesJson['membres'] as List)
              .whereType<Map>()
              .map((j) => MembreDisperseModele.fromJson(
                  Map<String, dynamic>.from(j)))
              .toList()
          : const <MembreDisperseModele>[];

      state = state.copyWith(
        serviteurs: _liste<ServiteurModele>(
          serviteursJson, (j) => ServiteurModele.fromJson(j)),
        heroes: heroes,
        temoignages: _liste<TemoignageModele>(
          temoignagesJson, (j) => TemoignageModele.fromJson(j)),
        enseignements: _liste<EnseignementModele>(
          enseignementsJson, (j) => EnseignementModele.fromJson(j)),
        videos: _liste<VideoModele>(videosJson, (j) => VideoModele.fromJson(j)),
        viesTransformees: _liste<VieTransformeeModele>(
          viesJson, (j) => VieTransformeeModele.fromJson(j)),
        annonces: _liste<AnnonceMinistereModele>(
          annoncesJson, (j) => AnnonceMinistereModele.fromJson(j)),
        liveEnCours: livesMap['enCours'] is Map<String, dynamic>
            ? LiveEnCoursModele.fromJson(
                livesMap['enCours'] as Map<String, dynamic>)
            : null,
        effacerLiveEnCours: livesMap['enCours'] is! Map<String, dynamic>,
        livesAVenir: _liste<LiveAVenirModele>(
          livesMap['aVenir'], (j) => LiveAVenirModele.fromJson(j)),
        dispersesTotal:
            (dispersesJson is Map<String, dynamic> && dispersesJson['total'] is num)
                ? (dispersesJson['total'] as num).toInt()
                : 0,
        dispersesParPays: dispersesJson is Map<String, dynamic> &&
                dispersesJson['parPays'] is Map<String, dynamic>
            ? (dispersesJson['parPays'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v is num ? v.toInt() : 0))
            : const <String, int>{},
        dispersesMembres: dispersesMembres,
        synchroniseLe: maj,
      );
    } catch (_) {
      // Base illisible (premier lancement) : état vide, la synchro viendra.
    }
  }

  List<T> _liste<T>(dynamic json, T Function(Map<String, dynamic>) parse) {
    if (json is! List) return <T>[];
    return json
        .whereType<Map>()
        .map((j) => parse(Map<String, dynamic>.from(j)))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════
  //  SYNCHRONISATION COMPLÈTE
  // ═════════════════════════════════════════════════════════════════

  /// Récupère TOUT le contenu public et le met en miroir dans SQLite.
  /// Silencieux en échec (l'état local reste affiché).
  /// ⭐ V2.4 — état `enCours` exposé aux écrans : indicateur de chargement
  /// visible PENDANT la synchronisation (plus jamais d'écran figé).
  Future<void> synchroniser() async {
    if (_enCours) return;
    if (!Connectivite.instance.enLigne) return;
    _enCours = true;
    state = state.copyWith(enCours: true);
    try {
      final data = await ApiClient.instance.getJson('/api/app/sync');
      if (data is! Map<String, dynamic>) return;

      // ── Écriture SQLite section par section (remplace) ──
      await _db.ecrireContenu('serviteurs', data['servants'] ?? []);
      await _db.ecrireContenu('heroes', data['heroes'] ?? {});
      await _db.ecrireContenu('temoignages', data['testimonies'] ?? []);
      await _db.ecrireContenu('enseignements', data['teachings'] ?? []);
      await _db.ecrireContenu('videos', data['videos'] ?? []);
      await _db.ecrireContenu('viesTransformees', data['viesTransformees'] ?? []);
      await _db.ecrireContenu('annonces', data['annonces'] ?? []);
      await _db.ecrireContenu('lives', data['lives'] ?? {});
      await _db.ecrireContenu('disperses', data['disperses'] ?? {});
      await _db.ecrireMeta(
        'syncedAt',
        data['syncedAt'] as String? ?? DateTime.now().toIso8601String(),
      );

      // ── Relecture → état Riverpod ──
      await chargerDepuisBase();
    } catch (_) {
      // Hors ligne / serveur indisponible : le contenu local reste
      // affiché, la prochaine tentative aura lieu au minuteur suivant.
    } finally {
      _enCours = false;
      // Notifie les écrans même en cas d'échec : l'indicateur s'arrête.
      if (state.enCours) state = state.copyWith(enCours: false);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  //  SURVEILLANCE LÉGÈRE (hash — web V4.10)
  // ═════════════════════════════════════════════════════════════════

  /// Compare le hash du bundle public : changé ⇒ resynchronisation.
  Future<void> _verifierHash() async {
    if (!Connectivite.instance.enLigne) return;
    try {
      final data =
          await ApiClient.instance.getJson('/api/app/content');
      if (data is! Map<String, dynamic>) return;
      final hash = data['hash'] as String?;
      if (hash == null || hash.isEmpty) return;
      final connu = await _db.lireMeta('hashContenu');
      if (connu != hash) {
        await _db.ecrireMeta('hashContenu', hash);
        if (connu != null) {
          // Premier hash mémorisé sans resynchronisation forcée si la
          // base vient d'être écrite ; sinon : le contenu a changé.
          await synchroniser();
        }
      }
    } catch (_) {
      // Silencieux.
    }
  }

  // ═════════════════════════════════════════════════════════════════
  //  OUTBOX — envoi différé « façon WhatsApp »
  // ═════════════════════════════════════════════════════════════════

  /// Envoie tous les messages en attente (FIFO). Un échec réseau
  /// interrompt la purge : les messages restent en file.
  static Future<void> purgerOutbox() async {
    if (!Connectivite.instance.enLigne) return;
    final repo = MessagesRepository();
    final db = DbLocal.instance;
    try {
      final file = await db.lireOutbox();
      for (final ligne in file) {
        final id = ligne['id'] as int;
        final conversationId = ligne['conversation_id'] as String;
        final contenu = ligne['contenu'] as String;
        final reponseA = ligne['reponse_a'] as String?;
        try {
          await repo.envoyer(
            conversationId,
            contenu,
            replyToId: reponseA,
          );
          await db.supprimerOutbox(id);
        } on ApiException catch (e) {
          if (e.reseauKO) {
            // Réseau retombé : on s'arrête, le reste attendra.
            return;
          }
          // Erreur applicative (401/403/400…) : ce message ne passera
          // jamais — on le retire pour ne pas bloquer la file.
          await db.supprimerOutbox(id);
        } catch (_) {
          await db.noterTentative(id);
        }
      }
    } catch (_) {
      // Base indisponible : rien à faire.
    }
  }
}

/// Provider du contenu — UN SEUL état partagé par tous les écrans.
final contenuProvider =
    StateNotifierProvider<ContenuController, ContenuState>(
  (ref) => ContenuController(),
);

/// Nombre de messages en attente d'envoi (badge tiroir/chat).
final outboxCompteurProvider = FutureProvider<int>((ref) async {
  return DbLocal.instance.compterOutbox();
});

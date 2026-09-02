/// Cycle de vie d'un APPEL (sortant ou entrant après décrochage) :
/// `sonnerie → en cours (chrono) → terminé (durée/issue)`.
///
/// Le statut distant (l'autre a décroché/raccroché) est reflété par le
/// polling `GET /calls/signal?callId=x` (2 s) — même machine à états que
/// le web V3.20.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/models/call_model.dart';
import '../data/repositories/calls_repository.dart';

enum CallPhase { sonnerie, enCours, terminee, refusee, manquee, annulee }

class ActiveCallState {
  final String callId;
  final String conversationId;

  /// ⭐ V1.1 — Pour TOUTE la durée de l'appel, l'info affichée est celle
  /// de L'APPELANT (nom + photo) sur un privé — jamais le nom du canal
  /// (qui est celui du destinataire) : même correctif que le web
  /// `acceptIncomingCall` V3.20.
  final String displayName;
  final String? displayAvatar;
  final String displaySubtitle;
  final bool isDirect;
  final bool isVideo;
  final bool jeSuisAppelant;

  final CallPhase phase;
  final DateTime? accepteAt;
  final String? resultText;

  const ActiveCallState({
    required this.callId,
    required this.conversationId,
    required this.displayName,
    this.displayAvatar,
    this.displaySubtitle = '',
    this.isDirect = false,
    this.isVideo = false,
    this.jeSuisAppelant = false,
    this.phase = CallPhase.sonnerie,
    this.accepteAt,
    this.resultText,
  });

  ActiveCallState copyWith({
    CallPhase? phase,
    DateTime? accepteAt,
    String? resultText,
  }) =>
      ActiveCallState(
        callId: callId,
        conversationId: conversationId,
        displayName: displayName,
        displayAvatar: displayAvatar,
        displaySubtitle: displaySubtitle,
        isDirect: isDirect,
        isVideo: isVideo,
        jeSuisAppelant: jeSuisAppelant,
        phase: phase ?? this.phase,
        accepteAt: accepteAt ?? this.accepteAt,
        resultText: resultText ?? this.resultText,
      );

  int get dureeSecondes =>
      accepteAt == null ? 0 : DateTime.now().difference(accepteAt!).inSeconds;
}

class ActiveCallController extends StateNotifier<ActiveCallState?> {
  final CallsRepository _repo = CallsRepository();
  Timer? _pollTimer;
  Timer? _chronoTimer;

  ActiveCallController() : super(null);

  /// Appel SORTANT : lancé depuis le bouton 📞/🎥 d'une conversation.
  Future<void> appeler({
    required String conversationId,
    required String conversationName,
    String? conversationAvatar,
    required String myName,
    String? myAvatar,
    bool video = false,
  }) async {
    final started = await _repo.demarrer(conversationId, video: video);
    state = ActiveCallState(
      callId: started.callId,
      conversationId: conversationId,
      // Sortant : c'est MOI l'appelant — j'affiche le nom de la
      // conversation (pour un privé : l'autre membre).
      displayName: conversationName,
      displayAvatar: conversationAvatar,
      displaySubtitle: isDirectLabel(started.conversationType),
      isDirect: started.conversationType == 'DIRECT',
      isVideo: video,
      jeSuisAppelant: true,
    );
    _startPolling();
  }

  /// Appel ENTRANT accepté depuis l'écran de sonnerie.
  ///
  /// ⭐ V1.1 — on conserve l'info de L'APPELANT (nom + photo + sous-ligne)
  /// issue du correctif : `IncomingCallModel.displayTitle` /
  /// `displayAvatar` titrent l'appelant sur un privé.
  Future<void> repondre(IncomingCallModel entrant, {String? myName}) async {
    await _repo.accepter(entrant.callId);
    state = ActiveCallState(
      callId: entrant.callId,
      conversationId: entrant.conversationId,
      displayName: entrant.displayTitle,
      displayAvatar: entrant.displayAvatar,
      displaySubtitle: entrant.isDirect ? 'Appel privé' : (entrant.displaySubtitle ?? ''),
      isDirect: entrant.isDirect,
      isVideo: entrant.isVideo,
      jeSuisAppelant: false,
      phase: CallPhase.enCours,
      accepteAt: DateTime.now(),
    );
    _startPolling();
    _startChrono();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConfig.callStatusPollSeconds),
      (_) => _pollStatus(),
    );
  }

  void _startChrono() {
    _chronoTimer?.cancel();
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Re-émet l'état pour rafraîchir le chrono.
      final s = state;
      if (s != null) state = s.copyWith();
    });
  }

  Future<void> _pollStatus() async {
    final s = state;
    if (s == null) return;
    try {
      final statut = await _repo.statut(s.callId);
      switch (statut.status) {
        case 'accepted':
          if (s.phase == CallPhase.sonnerie) {
            state = s.copyWith(phase: CallPhase.enCours, accepteAt: DateTime.now());
            _startChrono();
          }
          break;
        case 'declined':
          _terminer(CallPhase.refusee, 'Appel refusé');
          break;
        case 'missed':
          _terminer(CallPhase.manquee, 'Appel manqué');
          break;
        case 'cancelled':
          _terminer(CallPhase.annulee, 'Appel annulé');
          break;
        case 'ended':
          _terminer(
            CallPhase.terminee,
            statut.duration != null ? 'Appel terminé' : 'Appel terminé',
            dureeSec: statut.duration,
          );
          break;
        default:
          break; // ringing
      }
    } catch (_) {
      // Polling best-effort.
    }
  }

  void _terminer(CallPhase phase, String texte, {int? dureeSec}) {
    _pollTimer?.cancel();
    _chronoTimer?.cancel();
    final s = state;
    if (s == null) return;
    final duree = dureeSec ?? s.dureeSecondes;
    final libelle = phase == CallPhase.terminee && duree > 0 ? '$texte · ${_fmt(duree)}' : texte;
    state = s.copyWith(phase: phase, resultText: libelle);
    // L'UI affiche le résultat 2 s puis ferme.
    Future.delayed(const Duration(seconds: 2), () {
      if (state?.phase == phase) state = null;
    });
  }

  String _fmt(int sec) {
    if (sec < 60) return '$sec s';
    final m = sec ~/ 60;
    final r = sec % 60;
    return r > 0 ? '$m min $r s' : '$m min';
  }

  /// Raccrocher (appelant ou participant).
  Future<void> raccrocher() async {
    final s = state;
    if (s == null) return;
    try {
      await _repo.raccrocher(s.callId);
    } catch (_) {/* le statut serveur tranche au prochain polling */}
    if (s.phase == CallPhase.sonnerie) {
      _terminer(CallPhase.annulee, 'Appel annulé');
    } else {
      _terminer(CallPhase.terminee, 'Appel terminé');
    }
  }

  /// Fermeture manuelle de l'écran (après affichage de l'issue).
  void reinitialiser() {
    _pollTimer?.cancel();
    _chronoTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chronoTimer?.cancel();
    super.dispose();
  }

  String isDirectLabel(String? convType) =>
      convType == 'DIRECT' ? 'Appel privé' : 'Appel de groupe';
}

final activeCallProvider =
    StateNotifierProvider<ActiveCallController, ActiveCallState?>(
        (ref) => ActiveCallController());

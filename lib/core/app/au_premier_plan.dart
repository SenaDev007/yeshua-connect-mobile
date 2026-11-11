/// ⭐ V2.11 — PORTE D'ACTIVITÉ (app au premier plan ?).
///
/// Directive pasteur (cf. web v421 « la base Neon doit dormir ») : les
/// polls réseau de l'app mobile — conversations 10 s, chat 4 s, appels
/// entrants 3 s, statut d'appel 2 s, direct 3-25 s, hash de contenu
/// 60 s — ne doivent plus réveiller la base Neon ($158/3 mois, facturée
/// au compute actif) quand l'app est EN ARRIÈRE-PLAN.
///
/// AVANT : téléphone en poche ou écran éteint, les Timer.periodic
/// continuaient de tourner tant que le process vivait (Android ne gèle
/// l'app qu'après plusieurs minutes de doze) — chaque tick = 1+ requêtes
/// SQL qui entretiennent l'éveil de Neon, même la nuit.
///
/// PRINCIPE : un WidgetsBindingObserver racine (branché UNE fois dans
/// main.dart) met à jour l'état. Chaque poll consulte [actif] en tête
/// de son tick — pas de destruction/recréation de Timer, juste un tick
/// silencieux ; au retour au premier plan, le tick suivant (≤ 10 s)
/// reprend tout seul.
///
/// EXCEPTION — APPEL EN COURS : l'audio d'un appel vit légitimement en
/// arrière-plan (audio focus + WAKE_LOCK du manifeste) ; le poll de
/// statut d'appel (2 s) doit CONTINUER pendant un appel, sinon le
/// raccroché distant n'est plus détecté. [noteAppelEnCours] force donc
/// la porte ouverte le temps de l'appel (CallController).
///
/// NB appels ENTRANTS : leur détection (poll 3 s) s'arrête aussi en
/// arrière-plan — c'était déjà le comportement réel quelques minutes
/// après la mise en fond (gel Android du process) ; la voie fiable pour
/// joindre un téléphone en veille reste la notification push (FCM).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

class AuPremierPlan {
  AuPremierPlan._();

  static final AuPremierPlan instance = AuPremierPlan._();

  bool _actif = true;
  bool _appelEnCours = false;

  /// Vrai si l'app est VISIBLE (resumed / inactive — split-screen,
  /// transition iOS) OU si un appel est en cours.
  bool get actif => _actif || _appelEnCours;

  /// Changements d'état premier plan / arrière-plan (broadcast).
  final StreamController<bool> _flux = StreamController<bool>.broadcast();
  Stream<bool> get flux => _flux.stream;

  /// Appelé par l'observateur raciné dans main().
  void marquer(bool actif) {
    if (_actif == actif) return;
    _actif = actif;
    _flux.add(actif);
  }

  /// Positionné par le CallController : true à la sonnerie acceptée /
  /// au démarrage d'un appel sortant, false au raccroché.
  void noteAppelEnCours(bool enCours) {
    _appelEnCours = enCours;
  }
}

/// Observateur racine — ajouté dans main() via
/// `WidgetsBinding.instance.addObserver(ObservateurPremierPlan())`.
class ObservateurPremierPlan extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    // inactive : app encore visible (transition, split-screen) → actif.
    // paused / hidden / detached : arrière-plan → porte fermée.
    AuPremierPlan.instance.marquer(
      etat == AppLifecycleState.resumed ||
          etat == AppLifecycleState.inactive,
    );
  }
}

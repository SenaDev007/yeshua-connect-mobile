/// ⭐ V1.8 — SUIVI DE CONNECTIVITÉ.
///
/// Enveloppe `connectivity_plus` (API v6 : `List<ConnectivityResult>`) :
///   • `enLigne` : état courant (optimiste au démarrage — le vrai verdict
///     vient de la réussite/échec des requêtes, cf. CacheLocal) ;
///   • `flux` : stream broadcast pour le bandeau « Mode hors-ligne » et
///     la PAUSE des pollings (conversations 10 s, messages 4 s, appels
///     entrants 3 s) quand internet disparaît — plus de timeouts qui
///     s'accumulent, batterie préservée.
///
/// Le repli hors-ligne des DONNÉES ne dépend PAS de ce détecteur (le
/// wifi peut être actif alors que le serveur est down — cf. incident
/// Vercel) : `CacheLocal.getAvecCache` se déclenche sur l'échec réel
/// de la requête, quel que soit l'état de la connectivité.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class Connectivite {
  Connectivite._();

  static final Connectivite instance = Connectivite._();

  final StreamController<bool> _controleur = StreamController<bool>.broadcast();

  /// Optimiste par défaut : on préfère tenter la requête (le repli cache
  /// gère l'échec) plutôt que de déclarer l'app hors ligne à tort.
  bool _enLigne = true;
  bool _initialise = false;

  StreamSubscription<List<ConnectivityResult>>? _abonnement;

  /// État courant — vrai tant qu'aucune interface n'est déclarée morte.
  bool get enLigne => _enLigne;

  /// Changements d'état (broadcast — plusieurs auditeurs possibles).
  Stream<bool> get flux => _controleur.stream;

  /// À appeler une fois au démarrage (main) — idempotent.
  Future<void> initialiser() async {
    if (_initialise) return;
    _initialise = true;
    try {
      final resultats = await Connectivity().checkConnectivity();
      _evaluer(resultats);
      _abonnement = Connectivity().onConnectivityChanged.listen(_evaluer);
    } catch (_) {
      // Plateforme sans service de connectivité : on reste optimiste.
    }
  }

  void _evaluer(List<ConnectivityResult> resultats) {
    final enLigne = resultats.any((r) => r != ConnectivityResult.none);
    if (enLigne != _enLigne) {
      _enLigne = enLigne;
      _controleur.add(enLigne);
    }
  }
}

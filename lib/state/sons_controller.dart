/// ⭐ V2.8 — MODE MUET GLOBAL DES SONNERIES (demande pasteur).
///
/// « Je voudrais qu'il y ait quand même un bouton lié pour pouvoir mettre
/// le son, la sonnerie en muet au cas où ça dérangerait l'utilisateur.
/// L'utilisateur peut cliquer et activer le mode muet pour ne pas que ça
/// le dérange. Donc nous allons mettre ça partout où la sonnerie
/// résonne. »
///
/// Ce contrôleur couvre TOUTES les sonneries émises spontanément par
/// l'app :
///   • le shofar de l'intro (écran de lancement, 30 s) ;
///   • la sonnerie d'appel sortant (ringback.wav) ;
///   • (le shofar du calendrier reste un bouton « Écouter » explicite,
///     comme sur le web — l'utilisateur demande lui-même à l'entendre).
///
/// La préférence est PERSISTÉE en SharedPreferences : une fois coupée,
/// la sonnerie ne retentit plus aux prochains lancements. Le bouton de
/// bascule est disponible partout où la sonnerie résonne (splash, écran
/// d'appel) et en permanence dans le menu tiroir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lecture / écriture brutes de la préférence — utilisées aux points
/// d'émission (avant tout rendu, sans passer par un widget).
class Sons {
  static const clePrefs = 'mcl_sons_muets';

  /// Le mode muet est-il actif ? (défaut : son actif)
  static Future<bool> estMuet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(clePrefs) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persiste la préférence.
  static Future<void> definir(bool muet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(clePrefs, muet);
    } catch (_) {
      /* stockage indisponible : la session vit sans préférence */
    }
  }
}

/// État réactif du mode muet pour l'UI (splash, écran d'appel, tiroir).
class SonsMuetsController extends Notifier<bool> {
  @override
  bool build() {
    // Charge la préférence persistée en arrière-plan (défaut : son actif).
    Sons.estMuet().then((muet) {
      if (state != muet) state = muet;
    });
    return false;
  }

  /// Bascule le mode muet + persiste.
  Future<void> basculer() async {
    final nouveau = !state;
    state = nouveau;
    await Sons.definir(nouveau);
  }

  /// Coupe le son immédiatement (bouton des écrans où la sonnerie
  /// résonne) — idempotent.
  Future<void> couper() async {
    if (state) return;
    state = true;
    await Sons.definir(true);
  }
}

/// Provider réactif du mode muet.
final sonsMuetsProvider =
    NotifierProvider<SonsMuetsController, bool>(SonsMuetsController.new);

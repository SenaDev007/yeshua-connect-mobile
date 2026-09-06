/// ⭐ V1.8 — CACHE LOCAL HORS-LIGNE.
///
/// Le pasteur : « l'app doit pouvoir s'afficher pour qu'on puisse au moins
/// entrer et voir les conversations sans connexion internet — les anciennes
/// discussions, la lecture de la Bible, le calendrier. Seuls les appels,
/// les vidéos et les ENVOIS nécessitent la connexion. »
///
/// Principe (identique aux PWA du web) :
///   1. chaque réponse réseau utile est MISE EN CACHE localement ;
///   2. si le réseau/serveur échoue (hors ligne, injoignable, 5xx…),
///      la DERNIÈRE réponse en cache est servie à la place — l'app reste
///      utilisable en lecture ;
///   3. les écritures (envois, votes, appels…) échouent proprement avec
///      un message clair : elles exigent la connexion.
///
/// Stockage : un fichier JSON par clé dans `<documents>/cache-hors-ligne/`,
/// écriture ATOMIQUE (`.tmp` puis renommage) pour ne jamais corrompre un
/// cache si l'app est tuée en pleine écriture.
///
/// Anti-usure : une empreinte mémoire par clé évite de réécrire sur disque
/// un contenu identique (le polling de 10 s ne déclenche donc PAS d'écriture
/// quand rien n'a changé — batterie préservée).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';

class CacheLocal {
  CacheLocal._();
  static final CacheLocal instance = CacheLocal._();

  /// Taille maximale d'une entrée mise en cache (12 Mo) : les pages de
  /// messages contenant des images data-URL (base64) peuvent être lourdes ;
  /// au-delà, on renonce à cette entrée (jamais de cache illimité).
  static const int _tailleMaxOctets = 12 * 1024 * 1024;

  /// Clés canoniques (les autres clés sont construites par les dépôts).
  static const String cleSession = 'session-user';
  static const String cleConversations = 'conversations';
  static const String cleCalendrier = 'calendrier';
  static const String cleBibleVersions = 'bible-versions';

  Directory? _dossier;
  final Map<String, int> _empreintes = <String, int>{};

  // ═══════════════════════════════════════════════════════════════════
  //  PRIMITIVES DE FICHIER
  // ═══════════════════════════════════════════════════════════════════

  Future<Directory> _racine() async {
    final d = _dossier;
    if (d != null) return d;
    final base = await getApplicationDocumentsDirectory();
    final dossier = Directory('${base.path}/cache-hors-ligne');
    if (!dossier.existsSync()) dossier.createSync(recursive: true);
    _dossier = dossier;
    return dossier;
  }

  /// Nom de fichier sûr (les clés contiennent `/`, `:`…).
  File _fichier(String cle) {
    final sur = cle.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${sur.length > 120 ? sur.substring(sur.length - 120) : sur}.json');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LIRE / ÉCRIRE
  // ═══════════════════════════════════════════════════════════════════

  /// Met en cache [donnees] (Map/List décodées d'une réponse API).
  /// Ne lève JAMAIS : le cache est un confort, pas une dépendance.
  Future<void> sauvegarder(String cle, dynamic donnees) async {
    try {
      final contenu = jsonEncode(donnees);
      // Contenu inchangé depuis la dernière écriture → aucune écriture.
      if (_empreintes[cle] == _empreinte(contenu)) return;
      if (contenu.length > _tailleMaxOctets) return;
      final racine = await _racine();
      final cible = File('${racine.path}/${_fichier(cle).path}');
      final tmp = File('${cible.path}.tmp');
      await tmp.writeAsString(contenu, flush: true);
      await tmp.rename(cible.path);
      _empreintes[cle] = _empreinte(contenu);
    } catch (_) {
      // Disque plein / permissions : on vit sans cache.
    }
  }

  /// Lit une entrée en cache (null si absente/corrompue).
  Future<dynamic> charger(String cle) async {
    try {
      final racine = await _racine();
      final fichier = File('${racine.path}/${_fichier(cle).path}');
      if (!fichier.existsSync()) return null;
      return jsonDecode(await fichier.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Supprime une entrée (ex. session au logout).
  Future<void> supprimer(String cle) async {
    try {
      _empreintes.remove(cle);
      final racine = await _racine();
      final fichier = File('${racine.path}/${_fichier(cle).path}');
      if (fichier.existsSync()) await fichier.delete();
    } catch (_) {}
  }

  /// Efface tout le cache (déconnexion complète).
  Future<void> vider() async {
    try {
      _empreintes.clear();
      final racine = await _racine();
      if (racine.existsSync()) {
        await racine.delete(recursive: true);
      }
      _dossier = null;
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  //  REQUÊTE AVEC REPLI HORS-LIGNE
  // ═══════════════════════════════════════════════════════════════════

  /// Exécute [requete] (un GET réseau) :
  ///   • succès  → réponse mise en cache puis retournée ;
  ///   • échec RÉSEAU (hors ligne, serveur injoignable, 5xx, déploiement
  ///     absent — cf. `ApiException.reseauKO`) → la dernière réponse en
  ///     cache est servie si elle existe, sinon l'erreur est relancée ;
  ///   • échec d'AUTHENTIFICATION (401/403) → erreur relancée sans repli
  ///     (une session morte ne doit pas afficher de données fantômes).
  Future<dynamic> getAvecCache(
    String cle,
    Future<dynamic> Function() requete,
  ) async {
    try {
      final data = await requete();
      await sauvegarder(cle, data);
      return data;
    } on ApiException catch (e) {
      if (e.reseauKO) {
        final cache = await charger(cle);
        if (cache != null) return cache;
      }
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EMPREINTE ANTI-RÉÉCRITURE
  // ═══════════════════════════════════════════════════════════════════

  /// Empreinte rapide (FNV-1a échantillonné) — détecte un changement de
  /// contenu en O(n/97) sans stocker le contenu en mémoire.
  int _empreinte(String s) {
    var h = 0x811c9dc5;
    final n = s.length;
    for (var i = 0; i < n; i += 97) {
      h = ((h ^ s.codeUnitAt(i)) * 0x01000193) & 0x7fffffff;
    }
    return h ^ n;
  }
}

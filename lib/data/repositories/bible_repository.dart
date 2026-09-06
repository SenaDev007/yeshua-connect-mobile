/// Bible — accès aux routes du BACKEND PARTAGÉ (mêmes routes que le
/// workspace web BibleWorkspace.tsx) :
///
///   GET  /api/bible-v2/versions                → versions disponibles
///   GET  /api/bible-v2/{version}/{livre}/{chapitre} → chapitre complet
///   GET  /api/bible-v2/search?version&q        → recherche plein texte
///   GET  /api/bible/bookmarks                  → mes marque-pages (auth)
///   POST /api/bible/bookmarks                  → ajouter/mettre à jour
///   DEL  /api/bible/bookmarks/{id}             → supprimer
library;

import '../api/api_client.dart';
import '../models/bible_model.dart';

class BibleRepository {
  final ApiClient _api = ApiClient.instance;

  BibleRepository();

  /// Les 6 versions (fr-apee, en-kjv, en-bbe, es-rvr, pt-acf, ar-svd).
  Future<List<BibleVersionModel>> versions() async {
    final data = await _api.getJson('/api/bible-v2/versions');
    if (data is Map && data['versions'] is List) {
      return (data['versions'] as List)
          .map((v) => BibleVersionModel.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    }
    return const [];
  }

  /// Chapitre complet d'un livre.
  Future<ChapitreBibleModel> chapitre(String version, String livreId, int chapitre) async {
    final data = await _api.getJson('/api/bible-v2/$version/$livreId/$chapitre');
    if (data is Map) {
      return ChapitreBibleModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Chapitre introuvable.');
  }

  /// Recherche plein texte dans une version (limite 50 par défaut).
  Future<List<ResultatRechercheBibleModel>> recherche(
    String version,
    String q, {
    int limite = 50,
  }) async {
    if (q.trim().isEmpty) return const [];
    final data = await _api.getJson(
      '/api/bible-v2/search',
      queryParameters: {'version': version, 'q': q, 'limite': limite},
    );
    if (data is Map && data['resultats'] is List) {
      return (data['resultats'] as List)
          .map((r) => ResultatRechercheBibleModel.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    }
    return const [];
  }

  /// Mes marque-pages (persistés dans la base du projet mère).
  Future<List<MarquePageBibleModel>> marquePages() async {
    final data = await _api.getJson('/api/bible/bookmarks');
    if (data is Map && data['bookmarks'] is List) {
      return (data['bookmarks'] as List)
          .map((b) => MarquePageBibleModel.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
    }
    return const [];
  }

  /// Ajoute (ou met à jour — upsert serveur) un marque-page.
  Future<MarquePageBibleModel> ajouterMarquePage({
    required String version,
    required String livreId,
    required String livreNom,
    required int chapitre,
    required int verset,
    required String texte,
    String? note,
    String? couleur,
  }) async {
    final data = await _api.postJson(
      '/api/bible/bookmarks',
      body: {
        'version': version,
        'livreId': livreId,
        'livreNom': livreNom,
        'chapitre': chapitre,
        'verset': verset,
        'texte': texte,
        if (note != null && note.isNotEmpty) 'note': note,
        if (couleur != null) 'couleur': couleur,
      },
    );
    if (data is Map && data['bookmark'] is Map) {
      return MarquePageBibleModel.fromJson(
        Map<String, dynamic>.from(data['bookmark'] as Map),
      );
    }
    throw const ApiException("Impossible d'enregistrer le marque-page.");
  }

  /// Supprime un marque-page.
  Future<void> supprimerMarquePage(String id) async {
    await _api.deleteJson('/api/bible/bookmarks/$id');
  }

  // ═══════════════════════════════════════════════════════════════════
  // ⭐ V1.7 — OUTILS D'ÉTUDE (mêmes routes que le BibleWorkspace web)
  // ═══════════════════════════════════════════════════════════════════

  /// Lexique Strong — GET /api/bible-v2/strong/{numero} (H… ou G…).
  Future<EntreeStrongModel> strong(String numero) async {
    final data = await _api.getJson('/api/bible-v2/strong/${numero.toUpperCase()}');
    if (data is Map) {
      return EntreeStrongModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Entrée Strong introuvable.');
  }

  /// Verset hébraïque morphologique — GET /api/bible-v2/hebrew/{livre}/
  /// {chapitre}/{verset} (livre = nom OSHB : Gen, Exod, Ps…).
  Future<VersetHebreuModel> hebreu(String livreOshb, int chapitre, int verset) async {
    final data =
        await _api.getJson('/api/bible-v2/hebrew/$livreOshb/$chapitre/$verset');
    if (data is Map) {
      return VersetHebreuModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Verset hébraïque introuvable.');
  }

  /// Chapitre Peshitta araméenne — GET /api/bible-v2/peshitta/{livre}/
  /// {chapitre} (livre = nom anglais : Genesis, Exodus, Psalms…).
  Future<ChapitrePeshittaModel> peshitta(String livre, int chapitre) async {
    final data = await _api.getJson('/api/bible-v2/peshitta/$livre/$chapitre');
    if (data is Map) {
      return ChapitrePeshittaModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Chapitre Peshitta introuvable.');
  }

  /// Concordance Strong — GET /api/bible-v2/concordance/{numero}
  /// (définition + tous les versets hébraïques contenant le lemme).
  Future<ConcordanceModel> concordance(String numero, {int limite = 50}) async {
    final data = await _api.getJson(
      '/api/bible-v2/concordance/${numero.toUpperCase()}',
      queryParameters: {'limite': limite},
    );
    if (data is Map) {
      return ConcordanceModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Concordance indisponible.');
  }

  /// Verset parallèle dans une version donnée (comparatif web) —
  /// réutilise la route chapitre et isole le verset demandé.
  Future<VersetBibleModel?> versetParallele(
      String version, String livreId, int chapitre, int verset) async {
    try {
      final data = await _api.getJson('/api/bible-v2/$version/$livreId/$chapitre');
      if (data is Map) {
        final chap = ChapitreBibleModel.fromJson(Map<String, dynamic>.from(data));
        for (final v in chap.versets) {
          if (v.numero == verset) return v;
        }
      }
    } catch (_) {}
    return null;
  }
}

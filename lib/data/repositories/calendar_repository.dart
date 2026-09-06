/// Calendrier biblique — même backend que le web :
/// GET /api/calendrier-biblique/evenements (léger, ShofarNotifier)
/// et ?full=1 (ajoute 3 années bibliques sérialisées — CalendarWorkspace).
///
/// ⭐ V1.8 — HORS-LIGNE : les événements/années sont mis en cache à chaque
/// succès réseau et servis depuis le cache si le serveur est injoignable
/// (« visualiser le calendrier » sans internet — exigence pasteur).
///
/// ⭐ V1.9 — ROBUSTESSE + NAVIGATION CONTINUE (parité web V3.10) :
///   • si la réponse `?full=1` arrive SANS `annees` (réponse légère servie
///     par un déploiement plus ancien, proxy, CDN… — cause réelle du
///     « Vue mensuelle indisponible sur ce backend » constaté sur le
///     téléphone du pasteur), les 3 années sont récupérées INDIVIDUELLEMENT
///     via GET /api/calendrier-biblique/{annee} (route dédiée, même format)
///     puis la réponse complète assemblée est mise en cache pour le
///     hors-ligne ;
///   • `annee(anneeCivil)` charge À LA VOLÉE n'importe quelle année
///     (1900-2100, comme le web use-annees-bibliques) pour la navigation
///     continue entre années.
library;

import '../../core/offline/cache_local.dart';
import '../api/api_client.dart';
import '../models/calendar_model.dart';
class CalendarRepository {
  final ApiClient _api = ApiClient.instance;

  CalendarRepository();

  /// Bornes de l'API (identiques au web : ANNEE_MIN/ANNEE_MAX).
  static const int anneeMin = 1900;
  static const int anneeMax = 2100;

  /// Événements shofar (Shabbats + solennités) — sans [full], réponse
  /// légère ; avec [full], `annees` (3 années) incluse.
  ///
  /// ⭐ V1.9 — garantie : avec [full] (défaut), la valeur retournée
  /// contient TOUJOURS `annees` rempli si le serveur répond — soit parce
  /// que la réponse l'incluait, soit via la récupération individuelle.
  Future<({DateTime maintenant, int anneeBiblique, List<EvenementShofarModel> evenements, List<AnneeBibliqueModel> annees})>
      evenements({bool full = true}) async {
    var data = await CacheLocal.instance.getAvecCache(
      CacheLocal.cleCalendrier,
      () => _api.getJson(
        '/api/calendrier-biblique/evenements',
        queryParameters: full ? const {'full': '1'} : null,
      ),
    );

    // ⭐ V1.9 — réponse LÉGÈRE reçue alors que `full` était demandé
    // (déploiement/CDN/proxy plus ancien) → reconstruire les 3 années
    // via la route dédiée, puis ré-assembler une réponse COMPLÈTE et la
    // mettre en cache pour le hors-ligne.
    if (full && (data is! Map || (data['annees'] as List<dynamic>? ?? const []).isEmpty)) {
      if (data is! Map) {
        // Réponse illisible : retente une fois SANS cache intermédiaire.
        data = await _api.getJson(
          '/api/calendrier-biblique/evenements',
          queryParameters: const {'full': '1'},
        );
      }
      if (data is Map && (data['annees'] as List<dynamic>? ?? const []).isEmpty) {
        final ab = (data['anneeBiblique'] as num?)?.toInt() ??
            DateTime.now().year;
        final individuelles = await chargerAnneesIndividuelles(ab);
        if (individuelles.isNotEmpty) {
          // Ré-assemble la réponse complète (même forme que ?full=1) et
          // la mémorise : les prochains lancements hors-ligne auront les
          // 3 années directement depuis le cache.
          final complete = Map<String, dynamic>.from(data);
          complete['annees'] = [for (final a in individuelles) _serialiserAnnee(a)];
          await CacheLocal.instance.sauvegarder(
            CacheLocal.cleCalendrier,
            complete,
          );
          data = complete;
        }
      }
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return (
        maintenant: DateTime.tryParse(map['maintenant'] as String? ?? '') ?? DateTime.now(),
        anneeBiblique: (map['anneeBiblique'] as num?)?.toInt() ?? 0,
        evenements: (map['evenements'] as List<dynamic>? ?? [])
            .map((e) => EvenementShofarModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        annees: (map['annees'] as List<dynamic>? ?? const [])
            .map((a) => AnneeBibliqueModel.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
      );
    }
    throw const ApiException('Impossible de charger le calendrier biblique.');
  }

  /// ⭐ V1.9 — charge une année biblique précise (année CIVILE de départ,
  /// ex. 2026 → 2026-2027) : GET /api/calendrier-biblique/{annee}.
  /// Servie du cache hors-ligne si déjà consultée.
  Future<AnneeBibliqueModel?> annee(int anneeCivil) async {
    if (anneeCivil < anneeMin || anneeCivil > anneeMax) return null;
    try {
      final data = await CacheLocal.instance.getAvecCache(
        'calendrier-annee-$anneeCivil',
        () => _api.getJson('/api/calendrier-biblique/$anneeCivil'),
      );
      if (data is Map) {
        return AnneeBibliqueModel.fromJson(Map<String, dynamic>.from(data));
      }
    } on ApiException {
      return null; // hors ligne et jamais consultée : pas d'année
    }
    return null;
  }

  /// Récupère les années [ab-1, ab, ab+1] individuellement (miroir exact
  /// du web : `[anneeCourante-1, anneeCourante, anneeCourante+1]`).
  /// Une année injoignable est simplement ignorée (jamais d'échec global).
  Future<List<AnneeBibliqueModel>> chargerAnneesIndividuelles(int ab) async {
    final resultats = <AnneeBibliqueModel>[];
    for (final a in [ab - 1, ab, ab + 1]) {
      try {
        final r = await annee(a);
        if (r != null) resultats.add(r);
      } on ApiException {
        continue;
      }
    }
    resultats.sort((x, y) => x.annee.compareTo(y.annee));
    return resultats;
  }

  /// Re-sérialise une année vers la forme du `?full=1` (pour le cache).
  Map<String, dynamic> _serialiserAnnee(AnneeBibliqueModel a) => {
        'annee': a.annee,
        'libelle': a.libelle,
        'debut': a.debut.toIso8601String(),
        'fin': a.fin.toIso8601String(),
        'nombreJours': a.nombreJours,
        'jours': [
          for (final j in a.jours)
            {
              'jourDeAnnee': j.jourDeAnnee,
              'mois': j.mois,
              'nomMois': j.nomMois,
              'jourDuMois': j.jourDuMois,
              'jourDeSemaine': j.jourDeSemaine,
              'nomJourSemaine': j.nomJourSemaine,
              'estShabbat': j.estShabbat,
              'dateGregorienne': j.dateGregorienne.toIso8601String(),
              'trimestre': j.trimestre,
            },
        ],
        'fetes': [
          for (final f in a.fetes)
            {
              'id': f.id,
              'nomFr': f.nomFr,
              'nomHebrew': f.nomHebrew,
              'referenceEcritures': f.referenceEcritures,
              'description': f.description,
              'categorie': f.categorie,
              'couleur': f.couleur,
              'travailInterdit': f.travailInterdit,
              'dureeJours': f.dureeJours,
              'dateBiblique': f.dateBiblique,
              'dateGregorienne': f.dateGregorienne.toIso8601String(),
              'jourDeSemaine': f.jourDeSemaine,
              'joursRestants': f.joursRestants,
            },
        ],
      };
}
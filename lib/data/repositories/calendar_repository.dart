/// Calendrier biblique — même backend que le web :
/// GET /api/calendrier-biblique/evenements (léger, ShofarNotifier)
/// et ?full=1 (ajoute 3 années bibliques sérialisées — CalendarWorkspace).
library;

import '../api/api_client.dart';
import '../models/calendar_model.dart';

class CalendarRepository {
  final ApiClient _api = ApiClient.instance;

  CalendarRepository();

  /// Événements shofar (Shabbats + solennités) — sans [full], réponse
  /// légère ; avec [full], `annees` (3 années) incluse.
  Future<({DateTime maintenant, int anneeBiblique, List<EvenementShofarModel> evenements, List<AnneeBibliqueModel> annees})>
      evenements({bool full = true}) async {
    final data = await _api.getJson(
      '/api/calendrier-biblique/evenements',
      queryParameters: full ? const {'full': '1'} : null,
    );
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
}

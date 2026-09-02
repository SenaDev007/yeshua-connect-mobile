/// ⭐ V1.5 — Blocage/déblocage des membres — miroir exact des routes web
/// `/api/yeshua-connect/blocks` (V3.5) :
///   GET    ?includeBlockedMe=1 → mes blocages + ids qui m'ont bloqué ;
///   POST   { targetUserId }    → bloque (idempotent, audit log serveur) ;
///   DELETE ?targetUserId=…     → débloque (idempotent).
library;

import '../api/api_client.dart';
import '../models/blocks_models.dart';

class BlocksRepository {
  final ApiClient _api = ApiClient.instance;

  BlocksRepository();

  /// Mes blocages + (optionnel) ids des membres qui m'ont bloqué —
  /// utilisés pour griser les actions sans révéler QUI a bloqué.
  Future<({List<MembreBloqueModel> bloques, List<String> bloqueursIds})>
      lister({bool inclureBloqueurs = true}) async {
    final data = await _api.getJson(
      '/api/yeshua-connect/blocks',
      queryParameters:
          inclureBloqueurs ? {'includeBlockedMe': '1'} : null,
    );
    if (data is Map) {
      final bloques = (data['blocked'] as List? ?? [])
          .whereType<Map>()
          .map((m) => MembreBloqueModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final bloqueursIds = (data['blockedMeIds'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      return (bloques: bloques, bloqueursIds: bloqueursIds);
    }
    return (bloques: const <MembreBloqueModel>[], bloqueursIds: const <String>[]);
  }

  /// Bloque un membre (idempotent — effet immédiat côté serveur).
  Future<void> bloquer(String targetUserId) async {
    await _api.postJson(
      '/api/yeshua-connect/blocks',
      body: {'targetUserId': targetUserId},
    );
  }

  /// Débloque un membre (idempotent).
  Future<void> debloquer(String targetUserId) async {
    await _api.deleteJson(
      '/api/yeshua-connect/blocks',
      queryParameters: {'targetUserId': targetUserId},
    );
  }
}

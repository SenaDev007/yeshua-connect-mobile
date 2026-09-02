// ⭐ V1.5.1 — Test de compilation : importe l'arbre Dart COMPLET de
// l'application (main.dart → tous les packages, y compris les
// implémentations plateforme de `record`). Attrape les incohérences
// d'API entre sous-paquets (ex. record_linux 0.7.2 vs
// record_platform_interface 1.6.0) AVANT le build Android —
// `flutter analyze` seul ne compile pas le pub cache.
import 'package:flutter_test/flutter_test.dart';
import 'package:yeshua_connect/main.dart' as app;

void main() {
  test('l-arbre Dart complet compile (record, livekit, agora…)', () {
    // Référence symbolique : force la résolution de main.dart sans
    // exécuter l'app (pas de réseau, pas de DB).
    expect(app.main, isA<Function>());
  });
}

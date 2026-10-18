// ⭐ V2.3 — Tests du moteur markdown (articles professionnels).
//
// Vérifie que :
//   1. les emphases mal espacées sont réparées (anti-astérisques) ;
//   2. les structures correctes sont préservées (garde-fous) ;
//   3. les extraits plain-text n'affichent plus les marqueurs ;
//   4. le parseur de blocs produit la bonne structure d'article.
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yeshua_connect/core/utils/markdown_texte.dart';

void main() {
  group('normaliserMarkdown — réparations', () {
    test('gras avec espaces internes', () {
      expect(normaliserMarkdown('** ainsi ** le Seigneur'), '**ainsi** le Seigneur');
    });

    test('italique avec espaces internes', () {
      expect(normaliserMarkdown('* italique * simple'), '*italique* simple');
    });

    test('gras+italique avec espaces internes', () {
      expect(normaliserMarkdown('*** très *** important'), '***très*** important');
    });

    test('soulignés convertis en astérisques', () {
      expect(normaliserMarkdown('__gras__ et _italique_'), '**gras** et *italique*');
    });

    test('titre sans espace après dièse', () {
      expect(normaliserMarkdown('#Titre'), '# Titre');
    });

    test('guillemets français resserrés', () {
      expect(
        normaliserMarkdown('Il dit : * « viens » * demain'),
        'Il dit : *« viens »* demain',
      );
    });

    test('Israël préservé (traité en aval par _isololeMarkdown)', () {
      final r = normaliserMarkdown('les dispersés d\'Israël reviendront');
      expect(r, contains('Israël'));
      expect(r, isNot(contains('**')));
    });
  });

  group('normaliserMarkdown — garde-fous', () {
    test('multiplication intacte', () {
      expect(
        normaliserMarkdown('calcul : 3 * 4 * 5 = 60'),
        'calcul : 3 * 4 * 5 = 60',
      );
    });

    test('puces de liste intactes (pas de dévoration inter-lignes)', () {
      const src = 'transfigurés:\n* première vérité.\n* seconde vérité.';
      expect(normaliserMarkdown(src), src);
    });

    test('gras bien formé inchangé (idempotence)', () {
      expect(
        normaliserMarkdown('un **gras** et un *italique* propres'),
        'un **gras** et un *italique* propres',
      );
    });
  });

  group('nettoyerMarkdown — extraits plain-text', () {
    test('marqueurs retirés, mots conservés', () {
      expect(
        nettoyerMarkdown('**Le Shabbat** est *samedi*, # pas dimanche'),
        'Le Shabbat est samedi, # pas dimanche',
      );
    });

    test('retours à la ligne des puces gérés', () {
      final r = nettoyerMarkdown('intro:\n* un\n* deux');
      expect(r, isNot(contains('*')));
      expect(r, contains('un'));
    });
  });

  group('spansMarkdown — rendu inline', () {
    test('gras → TextSpan w800', () {
      final spans = spansMarkdown('un **mot** en gras');
      expect(spans.length, 3);
      final gras = spans.whereType<TextSpan>().toList()[1];
      expect(gras.text, 'mot');
      expect(gras.style?.fontWeight, FontWeight.w800);
    });

    test('italique → TextSpan italic', () {
      final spans = spansMarkdown('une *parole* douce');
      final ital = spans.whereType<TextSpan>().toList()[1];
      expect(ital.text, 'parole');
      expect(ital.style?.fontStyle, FontStyle.italic);
    });

    test('Isolélé — Israël rendu gras avec rappel', () {
      final spans = spansMarkdown('les dispersés d\'Israël');
      final plat = spans.map((s) => (s as TextSpan).text ?? '').join();
      expect(plat, contains('Isolélé'));
      expect(plat, contains('(Israël)'));
    });

    test('gras autour d\'Israël sans double délimiteur', () {
      final spans = spansMarkdown('le Dieu d\'**Israël** vit');
      final plat = spans.map((s) => (s as TextSpan).text ?? '').join();
      expect(plat, 'le Dieu d\'Isolélé (Israël) vit');
      expect(plat, isNot(contains('****')));
    });
  });

  group('blocs — structure d\'article', () {
    const article = '''
# Grand titre
Paragraphe d'introduction avec **du gras**.

## Section un
* première puce
* seconde puce avec *de l'italique*

> « Voici la parole de l'Éternel. »

1. première étape
2. seconde étape

---

Conclusion avec le peuple d'Israël.
''';

    testWidgets('rendu complet sans crash (titres, puces, citation, hr)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TexteMarkdown(article))),
      );
      expect(find.byType(TexteMarkdown), findsOneWidget);
      expect(find.textContaining('Grand titre'), findsOneWidget);
      expect(find.textContaining('première puce'), findsOneWidget);
      expect(find.textContaining('parole de l\'Éternel'), findsOneWidget);
      // Isolélé rendu avec son rappel Israël
      expect(find.textContaining('Isolélé'), findsWidgets);
    });

    testWidgets('texte vide — rendu vide sans crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TexteMarkdown(''))),
      );
      expect(find.byType(TexteMarkdown), findsOneWidget);
    });
  });
}

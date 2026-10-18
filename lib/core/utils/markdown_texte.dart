/// ⭐ V2.3 — MOTEUR MARKDOWN DE L'APP CHRIST LIBÈRE.
///
/// Exigence pasteur : les articles (enseignements, témoignages…)
/// doivent avoir une STRUCTURE PROFESSIONNELLE — les mots entre
/// `**astérisques**` ou `*astérisque*` s'affichent EN GRAS /
/// ITALIQUE, jamais avec leurs marqueurs.
///
/// Miroir Dart de la chaîne web V4.13 (src/lib/markdown-normal.ts +
/// markdown-text.tsx + isolole.tsx) — mêmes règles, même rendu :
///
///   · `**gras**`, `__gras__`            → texte en gras (w800)
///   · `*italique*`, `_italique_`        → texte en italique
///   · `***gras italique***`             → gras + italique
///   · `#` … `####` titres               → hiérarchie dorée/impériale
///   · `*` / `-` / `•` puces            → liste à puces dorées
///   · `1.` listes numérotées            → numéros dorés
///   · `>` citations                     → bloc verset (bordure or)
///   · `---` séparateur                  → filet or discret
///   · « Israël »                        → « Isolélé (Israël) » (gras)
///   · emphases mal espacées (« ** x ** », « * x * », « #Titre »)
///     → réparées automatiquement avant rendu.
///
/// ZÉRO DÉPENDANCE : pur Flutter/Material — aucun package ajouté.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
//  1. NORMALISATEUR (anti-astérisques visibles) — miroir web V4.13
// ═══════════════════════════════════════════════════════════════════

/// Répare les emphases mal formées rédigées dans le back-office.
/// Garde-fous : jamais à travers un retour à la ligne (protège les
/// puces), contenu italique commençant par lettre/guillemet (protège
/// « 3 * 4 * 5 »). Idempotent.
String normaliserMarkdown(String texte) {
  if (texte.isEmpty) return texte;
  var out = texte;

  // Titres : « #Titre » → « # Titre »
  out = out.replaceAllMapped(
    RegExp(r'^(#{1,4})([^\s#])', multiLine: true),
    (m) => '${m[1]} ${m[2]}',
  );

  // Gras+italique « *** *** » avec espaces internes (même ligne)
  out = out.replaceAllMapped(
    RegExp(r'\*\*\*[ \t]+([^*\n]+?)[ \t]+\*\*\*'),
    (m) => '***${m[1]}***',
  );

  // Gras « ** ** » avec espaces internes (même ligne)
  out = out.replaceAllMapped(
    RegExp(r'\*\*[ \t]+([^*\n]+?)[ \t]+\*\*'),
    (m) => '**${m[1]}**',
  );

  // Italique « * * » avec espaces internes (même ligne) — contenu
  // commençant par lettre ou guillemet, fermant suivi ponctuation.
  out = out.replaceAllMapped(
    RegExp(
        r'(^|[\s(\u00AB\u201C[])\*[ \t]+([a-zA-Z\u00C0-\u017F\u00AB\u201C"][^*\n]*?)[ \t]+\*(?=$|[\s).,;:!?\u00BB\u201D"])',
        multiLine: true),
    (m) => '${m[1]}*${m[2]}*',
  );

  // Soulignés → astérisques
  out = out.replaceAllMapped(
    RegExp(r'__([^_\n]+?)__'),
    (m) => '**${m[1]}**',
  );
  out = out.replaceAllMapped(
    RegExp(
        r'(^|[\s(\u00AB\u201C[])_([^_\n]+?)_(?=$|[\s).,;:!?\u00BB\u201D"])',
        multiLine: true),
    (m) => '${m[1]}*${m[2]}*',
  );

  // Guillemets français collés au gras : « ** « x » ** » → « **« x »** »
  out = out.replaceAllMapped(
    RegExp(r'\*\*[ \t]*\u00AB[ \t]*'),
    (m) => '**\u00AB',
  );
  out = out.replaceAllMapped(
    RegExp(r'[ \t]*\u00BB[ \t]*\*\*'),
    (m) => '\u00BB**',
  );

  return out;
}

/// Version PLAIN-TEXT : supprime les marqueurs (cartes de liste,
/// métadonnées, recherches) — n'affiche QUE les mots.
String nettoyerMarkdown(String texte) {
  if (texte.isEmpty) return texte;
  return normaliserMarkdown(texte)
      .replaceAll(RegExp(r'^#{1,6}[ \t]+', multiLine: true), '')
      .replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'_(.+?)_'), (m) => m[1]!)
      .replaceAll(RegExp(r'^\s*[-*\u2022][ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*>[ \t]?', multiLine: true), '')
      .replaceAll(RegExp(r'^[-=*_]{3,}[ \t]*$', multiLine: true), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

// ═══════════════════════════════════════════════════════════════════
//  2. ISOLÉLÉ (directive pastorale V3.45 — « Israël »)
// ═══════════════════════════════════════════════════════════════════

/// « …des dispersés d'Israël… » → « …des dispersés d'**Isolélé**
/// (Israël)… » au niveau markdown (consomme le gras existant autour
/// du mot pour ne jamais produire `****`).
String _isololeMarkdown(String texte) {
  // UNE SEULE passe (replaceAllMapped ne re-scanne jamais le texte
  // inséré — sinon « (Israël) » généré serait re-transformé en
  // « (Isolélé (Israël)) ») :
  //   · **Israël** (gras existant)  → **Isolélé** (Israël)
  //   · *Israël*  (italique existant) → *Isolélé* (Israël)
  //   · Israël (nu)                 → **Isolélé** (Israël)
  final motif = RegExp(
      r'\*\*[ \t]*Isra[ëe]l[ \t]*\*\*|\*[ \t]*Isra[ëe]l[ \t]*\*|\bIsra[ëe]l\b');
  return texte.replaceAllMapped(motif, (m) {
    final t = m[0]!;
    if (t.startsWith('**')) return '**Isolélé** (Israël)';
    if (t.startsWith('*')) return '*Isolélé* (Israël)';
    return '**Isolélé** ($t)';
  });
}

// ═══════════════════════════════════════════════════════════════════
//  3. PARSEUR INLINE — gras / italique / Isolélé
// ═══════════════════════════════════════════════════════════════════

/// Découpe un texte en spans riches : `**gras**`, `*italique*`,
/// `***gras italique***` + Isolélé. Équivalent Dart du <IsololeText>
/// et du MarkdownInline web combinés.
List<InlineSpan> spansMarkdown(
  String texte, {
  TextStyle? style,
  TextStyle? styleGras,
  TextStyle? styleItalique,
}) {
  if (texte.isEmpty) return const [];
  final source = _isololeMarkdown(normaliserMarkdown(texte));

  final gras = styleGras ??
      style?.copyWith(fontWeight: FontWeight.w800) ??
      const TextStyle(fontWeight: FontWeight.w800);
  final italique = styleItalique ??
      style?.copyWith(fontStyle: FontStyle.italic) ??
      const TextStyle(fontStyle: FontStyle.italic);
  final grasItalique = (styleGras ?? style)?.copyWith(
          fontWeight: FontWeight.w800, fontStyle: FontStyle.italic) ??
      const TextStyle(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic);

  final spans = <InlineSpan>[];
  // NB : contrairement à JavaScript, String.split(RegExp) de Dart ne
  // conserve PAS les groupes capturants (les délimiteurs seraient
  // perdus) → parcours par allMatches, curseur sur le texte brut.
  final motif = RegExp(r'\*\*\*[^*\n]+?\*\*\*|\*\*[^*\n]+?\*\*|\*[^*\n]+?\*');
  var curseur = 0;
  for (final m in motif.allMatches(source)) {
    if (m.start > curseur) {
      spans.add(TextSpan(text: source.substring(curseur, m.start), style: style));
    }
    final t = m[0]!;
    if (t.startsWith('***') && t.length > 6) {
      spans.add(TextSpan(text: t.substring(3, t.length - 3), style: grasItalique));
    } else if (t.startsWith('**') && t.length > 4) {
      spans.add(TextSpan(text: t.substring(2, t.length - 2), style: gras));
    } else {
      spans.add(TextSpan(text: t.substring(1, t.length - 1), style: italique));
    }
    curseur = m.end;
  }
  if (curseur < source.length) {
    spans.add(TextSpan(text: source.substring(curseur), style: style));
  }
  return spans;
}

// ═══════════════════════════════════════════════════════════════════
//  4. PARSEUR DE BLOCS — structure d'article
// ═══════════════════════════════════════════════════════════════════

enum _TypeBloc { titre, paragraphe, citation, puce, numero, separateur }

class _Bloc {
  final _TypeBloc type;
  final String texte;
  final int niveauTitre; // 1-4 pour les titres ; 0/1 pour l'indentation des listes
  final String numero; // « 1. », « 2. »… pour les listes ordonnées
  const _Bloc(this.type, this.texte, {this.niveauTitre = 0, this.numero = ''});
}

List<_Bloc> _parserBlocs(String contenu) {
  final blocs = <_Bloc>[];
  final lignes = contenu.split('\n');
  final paragraphe = <String>[];

  void viderParagraphe() {
    if (paragraphe.isEmpty) return;
    blocs.add(_Bloc(_TypeBloc.paragraphe, paragraphe.join(' ')));
    paragraphe.clear();
  }

  for (var brute in lignes) {
    final ligne = brute.rstrip();
    if (ligne.isEmpty) {
      viderParagraphe();
      continue;
    }

    // Titres # ## ### ####
    final titre = RegExp(r'^(#{1,6})[ \t]+(.*)$').firstMatch(ligne);
    if (titre != null) {
      viderParagraphe();
      blocs.add(_Bloc(
        _TypeBloc.titre,
        titre.group(2)!.trim(),
        niveauTitre: titre.group(1)!.length.clamp(1, 4),
      ));
      continue;
    }

    // Séparateur --- *** ___ (3+ répétitions seules sur la ligne)
    if (RegExp(r'^([-*_])[ \t]*\1[ \t]*\1[ \t]*$').hasMatch(ligne.trim())) {
      viderParagraphe();
      blocs.add(const _Bloc(_TypeBloc.separateur, ''));
      continue;
    }

    // Citation > texte
    final citation = RegExp(r'^>[ \t]?(.*)$').firstMatch(ligne);
    if (citation != null) {
      viderParagraphe();
      blocs.add(_Bloc(_TypeBloc.citation, citation.group(1)!.trim()));
      continue;
    }

    // Puce * - • texte (l'indentation crée un niveau)
    final puce = RegExp(r'^([ \t]*)[*\-\u2022][ \t]+(.*)$').firstMatch(ligne);
    if (puce != null) {
      viderParagraphe();
      final indent = puce.group(1)!.length >= 2 ? 1 : 0;
      blocs.add(_Bloc(_TypeBloc.puce, puce.group(2)!.trim(), niveauTitre: indent));
      continue;
    }

    // Liste numérotée 1. 2) texte
    final numero = RegExp(r'^([ \t]*)([0-9]{1,3})[.)][ \t]+(.*)$').firstMatch(ligne);
    if (numero != null) {
      viderParagraphe();
      final indent = numero.group(1)!.length >= 2 ? 1 : 0;
      blocs.add(_Bloc(_TypeBloc.numero, numero.group(3)!.trim(),
          niveauTitre: indent, numero: '${numero.group(2)}.'));
      continue;
    }

    // Ligne de paragraphe (fusion avec les suivantes)
    paragraphe.add(ligne.trim());
  }
  viderParagraphe();
  return blocs;
}

// ═══════════════════════════════════════════════════════════════════
//  5. WIDGET — ARTICLE PROFESSIONNEL COMPLET
// ═══════════════════════════════════════════════════════════════════

/// Rendu intégral d'un article markdown avec la charte Christ Libère :
/// titres hiérarchisés (or impérial), versets en blocs citation bordés
/// d'or, listes à puces dorées, gras/italique, Isolélé.
///
/// Usage : `TexteMarkdown(enseignement.contenu)`.
class TexteMarkdown extends StatelessWidget {
  final String contenu;

  /// Taille du corps de texte (14.5 par défaut — fiche de lecture).
  final double tailleCorps;

  const TexteMarkdown(this.contenu, {super.key, this.tailleCorps = 14.5});

  @override
  Widget build(BuildContext context) {
    final blocs = _parserBlocs(normaliserMarkdown(contenu));
    if (blocs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocs.length; i++) ..._construireBloc(blocs[i], i == 0),
      ],
    );
  }

  List<Widget> _construireBloc(_Bloc bloc, bool premier) {
    final margeHaut = premier ? 0.0 : 13.0;

    switch (bloc.type) {
      // ── TITRES : hiérarchie professionnelle ──
      case _TypeBloc.titre:
        final n = bloc.niveauTitre;
        if (n <= 1) {
          return [
            SizedBox(height: margeHaut + 5),
            Text.rich(
              TextSpan(children: spansMarkdown(bloc.texte)),
              style: const TextStyle(
                color: AppColors.texte,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
          ];
        }
        if (n == 2) {
          return [
            SizedBox(height: margeHaut + 6),
            Text.rich(
              TextSpan(children: spansMarkdown(bloc.texte)),
              style: const TextStyle(
                color: AppColors.texte,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            // Filet or sous les H2 — même design que le web
            Container(
              margin: const EdgeInsets.only(top: 5, bottom: 2),
              height: 1,
              color: AppColors.or.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 6),
          ];
        }
        if (n == 3) {
          return [
            SizedBox(height: margeHaut + 4),
            Text.rich(
              TextSpan(children: spansMarkdown(
                bloc.texte,
                style: const TextStyle(
                  color: AppColors.or,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
                styleGras: const TextStyle(
                  color: AppColors.orPastel,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              )),
            ),
            const SizedBox(height: 5),
          ];
        }
        return [
          SizedBox(height: margeHaut + 2),
          Text.rich(
            TextSpan(children: spansMarkdown(bloc.texte)),
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
        ];

      // ── PARAGRAPHE ──
      case _TypeBloc.paragraphe:
        return [
          SizedBox(height: margeHaut),
          Text.rich(
            TextSpan(
              children: spansMarkdown(
                bloc.texte,
                style: TextStyle(
                  color: AppColors.texte,
                  fontSize: tailleCorps,
                  height: 1.7,
                ),
                styleGras: TextStyle(
                  color: AppColors.orPastel,
                  fontSize: tailleCorps,
                  height: 1.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ];

      // ── CITATION / VERSET — bloc professionnel bordé d'or ──
      case _TypeBloc.citation:
        return [
          SizedBox(height: margeHaut + 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.pourpre.withValues(alpha: 0.75),
              border: const Border(
                left: BorderSide(color: AppColors.or, width: 3),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text.rich(
              TextSpan(
                children: spansMarkdown(
                  bloc.texte,
                  style: TextStyle(
                    color: AppColors.orPastel,
                    fontSize: tailleCorps,
                    height: 1.65,
                    fontStyle: FontStyle.italic,
                  ),
                  styleGras: TextStyle(
                    color: AppColors.or,
                    fontSize: tailleCorps,
                    height: 1.65,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
        ];

      // ── PUCE — liste à puce dorée ──
      case _TypeBloc.puce:
        return [
          SizedBox(height: premier ? 0 : 7),
          Padding(
            padding: EdgeInsets.only(left: 18.0 * bloc.niveauTitre),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 9),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.or,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: spansMarkdown(
                        bloc.texte,
                        style: TextStyle(
                          color: AppColors.texte,
                          fontSize: tailleCorps,
                          height: 1.65,
                        ),
                        styleGras: TextStyle(
                          color: AppColors.orPastel,
                          fontSize: tailleCorps,
                          height: 1.65,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];

      // ── NUMÉRO — liste ordonnée dorée ──
      case _TypeBloc.numero:
        return [
          SizedBox(height: premier ? 0 : 7),
          Padding(
            padding: EdgeInsets.only(left: 18.0 * bloc.niveauTitre),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 2),
                _NumeroOr(texte: bloc.numero),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: spansMarkdown(
                        bloc.texte,
                        style: TextStyle(
                          color: AppColors.texte,
                          fontSize: tailleCorps,
                          height: 1.65,
                        ),
                        styleGras: TextStyle(
                          color: AppColors.orPastel,
                          fontSize: tailleCorps,
                          height: 1.65,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];

      // ── SÉPARATEUR — filet or discret ──
      case _TypeBloc.separateur:
        return [
          SizedBox(height: margeHaut + 4),
          Container(height: 1, color: AppColors.or.withValues(alpha: 0.22)),
          SizedBox(height: margeHaut + 4),
        ];
    }
  }
}

/// Numéro de liste ordonnée, doré et gras (cercle discret).
class _NumeroOr extends StatelessWidget {
  final String texte;
  const _NumeroOr({required this.texte});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: Text(
        texte,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.or,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          height: 1.6,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  EXTENSION — rstrip() (fin de ligne sans espace)
// ═══════════════════════════════════════════════════════════════════

extension _RStrip on String {
  String rstrip() => replaceFirst(RegExp(r'[ \t]+$'), '');
}

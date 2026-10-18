/// ⭐ ÉCRAN DÉDIÉ — Bible (parité web V2.6 / BibleWorkspace) :
///
///   • 6 versions (fr-apee, en-kjv, en-bbe, es-rvr, pt-acf, ar-svd) ;
///   • navigation 66 livres AT/NT + chapitres, chapitre ◀ ▶ ;
///   • versets numérotés — tap → Marque-page / Partager dans un chat
///     (message VERSE, même format que le web) ;
///   • recherche plein texte de la version courante ;
///   • marque-pages persistés dans la base du projet mère (partagés
///     avec le web : marquer sur mobile = retrouver sur le web).
///
/// ⭐⭐ V1.7 — OUTILS D'ÉTUDE COMPLETS (mêmes onglets que le web) :
///   Lexique Strong · Texte hébraïque · Peshitta araméenne ·
///   Concordance · Comparatif — les routes API sont identiques au
///   BibleWorkspace web (le pasteur : « Je n'ai pas retrouvé tout ça
///   sur le mobile » → comblé).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'menu_tiroir.dart';
import '../../data/models/bible_model.dart';
import '../../data/repositories/bible_repository.dart';
import '../../state/bible_controller.dart';
import '../../state/conversations_controller.dart';

class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(bibleProvider);

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: AppColors.nuit,
        // ⭐ V2.4 — tiroir du ministère (accès aux autres modules).
        drawer: const MenuTiroir(),
        appBar: AppBar(
          title: const Text('Bible'),
          // ⭐ V2.4 — hamburger quand racine ; flèche RETOUR conservée
          // quand la page est poussée (contexte public /app/bible).
          leading: Navigator.of(context).canPop()
              ? null
              : Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.or),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
          actions: [
            // Sélecteur de version — « FR · ÉPÉE ».
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _choisirVersion(context, ref),
                icon: const Icon(Icons.translate, size: 18, color: AppColors.or),
                label: Text(
                  etat.versionCode,
                  style: const TextStyle(
                    color: AppColors.orPastel,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.or,
            labelColor: AppColors.or,
            unselectedLabelColor: AppColors.texteSecondaire,
            tabs: [
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Lecture'),
              Tab(icon: Icon(Icons.search), text: 'Recherche'),
              Tab(icon: Icon(Icons.tag), text: 'Strong'),
              Tab(icon: Icon(Icons.article_outlined), text: 'Hébreu'),
              Tab(icon: Icon(Icons.language), text: 'Peshitta'),
              Tab(icon: Icon(Icons.shield_outlined), text: 'Concordance'),
              Tab(icon: Icon(Icons.view_column_outlined), text: 'Comparatif'),
              Tab(icon: Icon(Icons.bookmark_border), text: 'Marque-pages'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _VueLectureWrapper(),
            _VueRecherche(),
            _OngletStrong(),
            _OngletHebreu(),
            _OngletPeshitta(),
            _OngletConcordance(),
            _OngletComparatif(),
            _VueMarquePages(),
          ],
        ),
        bottomSheet: etat.versetSelectionne != null
            ? _FeuilleVerset(etat: etat)
            : null,
      ),
    );
  }

  void _choisirVersion(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Version biblique',
                style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            for (final code in const [
              'fr-apee',
              'en-kjv',
              'en-bbe',
              'es-rvr',
              'pt-acf',
              'ar-svd',
            ])
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.texteSecondaire),
                title: Text(
                  _nomVersion(code),
                  style: const TextStyle(color: AppColors.texte),
                ),
                trailing: ref.read(bibleProvider).versionCode == code
                    ? const Icon(Icons.check, color: AppColors.or)
                    : null,
                onTap: () {
                  ref.read(bibleProvider.notifier).changerVersion(code);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _nomVersion(String code) => switch (code) {
        'fr-apee' => 'Bible de l\u2019Épée (Français)',
        'en-kjv' => 'King James Version (English)',
        'en-bbe' => 'Bible in Basic English',
        'es-rvr' => 'Reina Valera (Español)',
        'pt-acf' => 'Almeida Corrigida Fiel (Português)',
        'ar-svd' => 'Arabic Bible (العربية)',
        _ => code,
      };
}

// ═══════════════════════════════════════════════════════════════════════
//  LECTURE
// ═══════════════════════════════════════════════════════════════════════

/// Relais vers [_VueLecture] — la TabBarView est désormais const (8 onglets).
class _VueLectureWrapper extends ConsumerWidget {
  const _VueLectureWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VueLecture(etat: ref.watch(bibleProvider));
  }
}

class _VueLecture extends ConsumerWidget {
  const _VueLecture({required this.etat});

  final BibleState etat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (etat.chargement) {
      return const Center(child: CircularProgressIndicator(color: AppColors.or));
    }
    if (etat.erreur != null && etat.chapitreData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.danger, size: 44),
              const SizedBox(height: 12),
              Text(
                etat.erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texteSecondaire),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.read(bibleProvider.notifier).rafraichir(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final chapitre = etat.chapitreData;
    final livre = livreBibleParId(etat.livreId);
    final titreLivre = chapitre?.livre ?? livre?.nom ?? etat.livreId;

    return Column(
      children: [
        // Bandeau navigation : livre · chapitre · ◀ ▶
        Container(
          color: AppColors.pourpre,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _choisirLivre(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.library_books, size: 18, color: AppColors.or),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$titreLivre ${etat.chapitre}',
                            style: const TextStyle(
                              color: AppColors.texte,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18, color: AppColors.texteSecondaire),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Chapitre précédent',
                icon: const Icon(Icons.chevron_left, color: AppColors.orPastel),
                onPressed: () => ref.read(bibleProvider.notifier).chapitrePrecedent(),
              ),
              IconButton(
                tooltip: 'Chapitre suivant',
                icon: const Icon(Icons.chevron_right, color: AppColors.orPastel),
                onPressed: () => ref.read(bibleProvider.notifier).chapitreSuivant(),
              ),
            ],
          ),
        ),
        if (chapitre != null && chapitre.fallback)
          Container(
            width: double.infinity,
            color: AppColors.or.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(10),
            child: const Text(
              'Version allégée : ce chapitre provient des versets de secours.',
              style: TextStyle(color: AppColors.orPastel, fontSize: 12),
            ),
          ),
        // Versets
        Expanded(
          child: chapitre == null || chapitre.versets.isEmpty
              ? const Center(
                  child: Text(
                    'Chapitre indisponible dans cette version.',
                    style: TextStyle(color: AppColors.texteSecondaire),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  itemCount: chapitre.versets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final verset = chapitre.versets[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => ref
                          .read(bibleProvider.notifier)
                          .selectionnerVerset(verset),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${verset.numero} ',
                                style: const TextStyle(
                                  color: AppColors.or,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: verset.texte,
                                style: const TextStyle(
                                  color: AppColors.texte,
                                  height: 1.55,
                                  fontSize: 15.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _choisirLivre(BuildContext context, WidgetRef ref) {
    final etat = ref.read(bibleProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Choisir un livre',
                style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            _sectionTestament(context, ref, 'Ancien Testament', true, etat),
            _sectionTestament(context, ref, 'Nouveau Testament', false, etat),
          ],
        ),
      ),
    );
  }

  Widget _sectionTestament(
    BuildContext context,
    WidgetRef ref,
    String titre,
    bool estAT,
    BibleState etat,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              titre,
              style: const TextStyle(
                color: AppColors.texteSecondaire,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final livre in kLivresBible.where((l) => l.estAncienTestament == estAT))
                ActionChip(
                  backgroundColor: etat.livreId == livre.id
                      ? AppColors.or.withValues(alpha: 0.25)
                      : AppColors.nuitClair,
                  label: Text(
                    livre.nom,
                    style: TextStyle(
                      color: etat.livreId == livre.id ? AppColors.or : AppColors.texte,
                      fontWeight: etat.livreId == livre.id ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: AppColors.pourpre,
                      builder: (sheetContext) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${livre.nom} — chapitre',
                                style: const TextStyle(
                                  color: AppColors.or,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var c = 1; c <= livre.chapitres; c++)
                                  ActionChip(
                                    backgroundColor: AppColors.nuitClair,
                                    label: Text(
                                      '$c',
                                      style: const TextStyle(color: AppColors.texte),
                                    ),
                                    onPressed: () {
                                      Navigator.of(sheetContext).pop();
                                      ref.read(bibleProvider.notifier).ouvrir(livre.id, c);
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════
//  RECHERCHE
// ═══════════════════════════════════════════════════════════════════════

class _VueRecherche extends ConsumerStatefulWidget {
  const _VueRecherche();

  @override
  ConsumerState<_VueRecherche> createState() => _VueRechercheState();
}

class _VueRechercheState extends ConsumerState<_VueRecherche> {
  final _controleur = TextEditingController();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(bibleProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controleur,
            style: const TextStyle(color: AppColors.texte),
            textInputAction: TextInputAction.search,
            onSubmitted: (q) => ref.read(bibleProvider.notifier).rechercher(q),
            decoration: InputDecoration(
              hintText: 'Rechercher un passage… (ex. « paix »)',
              hintStyle: const TextStyle(color: AppColors.texteEteint),
              prefixIcon: const Icon(Icons.search, color: AppColors.or),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: AppColors.or),
                onPressed: () => ref.read(bibleProvider.notifier).rechercher(_controleur.text),
              ),
              filled: true,
              fillColor: AppColors.pourpre,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (etat.rechercheEnCours)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: AppColors.or),
          ),
        Expanded(
          child: etat.resultats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      etat.requete.isEmpty
                          ? 'Recherche plein texte dans la version courante.'
                          : 'Aucun verset trouvé pour « ${etat.requete} ».',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.texteSecondaire),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: etat.resultats.length,
                  separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final r = etat.resultats[i];
                    return ListTile(
                      title: Text(
                        r.reference,
                        style: const TextStyle(
                          color: AppColors.or,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        r.texte,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texteSecondaire,
                          height: 1.4,
                        ),
                      ),
                      onTap: () {
                        ref.read(bibleProvider.notifier).ouvrir(r.livreId, r.chapitre);
                        ref.read(bibleProvider.notifier).changerOnglet(BibleOnglet.lecture);
                        DefaultTabController.of(context).animateTo(0);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MARQUE-PAGES (base partagée avec le web)
// ═══════════════════════════════════════════════════════════════════════

class _VueMarquePages extends ConsumerWidget {
  const _VueMarquePages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(bibleProvider);
    if (etat.marquePages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 48, color: AppColors.texteEteint),
              SizedBox(height: 12),
              Text(
                'Aucun marque-page — touchez un verset en lecture\n'
                'puis « Marquer ce verset ».',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.texteSecondaire, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: etat.marquePages.length,
      separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final m = etat.marquePages[i];
        return ListTile(
          leading: const Icon(Icons.bookmark, color: AppColors.or),
          title: Text(
            m.reference,
            style: const TextStyle(
              color: AppColors.or,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            m.texte,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.texteSecondaire, height: 1.4),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Supprimer le marque-page',
            onPressed: () => ref.read(bibleProvider.notifier).supprimerMarquePage(m.id),
          ),
          onTap: () {
            ref.read(bibleProvider.notifier).changerVersion(m.version);
            ref.read(bibleProvider.notifier).ouvrir(m.livreId, m.chapitre);
            ref.read(bibleProvider.notifier).changerOnglet(BibleOnglet.lecture);
            DefaultTabController.of(context).animateTo(0);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET DU VERSET SÉLECTIONNÉ
// ═══════════════════════════════════════════════════════════════════════

class _FeuilleVerset extends ConsumerWidget {
  const _FeuilleVerset({required this.etat});

  final BibleState etat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verset = etat.versetSelectionne;
    if (verset == null) return const SizedBox.shrink();
    final livre = livreBibleParId(etat.livreId);
    final reference = '${livre?.nom ?? etat.livreId} ${etat.chapitre}:${verset.numero}';

    return Container(
      color: AppColors.pourpre,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reference,
                  style: const TextStyle(
                    color: AppColors.or,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.texteSecondaire, size: 20),
                onPressed: () => ref.read(bibleProvider.notifier).selectionnerVerset(null),
              ),
            ],
          ),
          Text(
            verset.texte,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texteSecondaire,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.or,
                    side: const BorderSide(color: AppColors.orFonce),
                  ),
                  onPressed: () async {
                    try {
                      await ref.read(bibleProvider.notifier).marquerVersetSelectionne();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verset marqué (visible aussi sur le web)')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Marquer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.or,
                    foregroundColor: AppColors.nuit,
                  ),
                  onPressed: () => _partager(context, ref, reference),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Partage le verset dans une conversation — dialogue de choix (le web
  /// partage dans la conversation active ; mobile : « Partager vers… »).
  void _partager(BuildContext context, WidgetRef ref, String reference) {
    final conversations = ref.read(conversationsProvider).conversations;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Partager le verset dans…',
                style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            if (conversations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Aucune conversation — rejoignez un canal d\u2019abord.',
                  style: TextStyle(color: AppColors.texteSecondaire),
                ),
              ),
            for (final conv in conversations.take(12))
              ListTile(
                leading: Icon(
                  conv.isDirect ? Icons.person : Icons.tag,
                  color: AppColors.typeAccent(conv.type),
                ),
                title: Text(
                  conv.displayName,
                  style: const TextStyle(color: AppColors.texte),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    await ref.read(bibleProvider.notifier).partagerVerset(conv.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verset $reference partagé dans ${conv.displayName}')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ⭐ V1.7 — OUTILS D'ÉTUDE (parité BibleWorkspace web)
// Lexique Strong · Texte hébraïque · Peshitta araméenne · Concordance ·
// Comparatif — mêmes routes API que le web, même vocabulaire.
// ═══════════════════════════════════════════════════════════════════════

/// Abréviations OSHB des 39 livres de l'AT (route /hebrew) — miroir du
/// OSHB_VERS_ID web, dans l'ordre canonique.
const Map<String, String> kOshbParLivreId = {
  'gn': 'Gen', 'ex': 'Exod', 'lv': 'Lev', 'nb': 'Num', 'dt': 'Deut',
  'js': 'Josh', 'jg': 'Judg', 'rt': 'Ruth', '1sm': '1Sam', '2sm': '2Sam',
  '1kg': '1Kgs', '2kg': '2Kgs', '1ch': '1Chr', '2ch': '2Chr', 'er': 'Ezra',
  'ne': 'Neh', 'est': 'Esth', 'jb': 'Job', 'ps': 'Ps', 'pv': 'Prov',
  'ec': 'Eccl', 'ct': 'Song', 'es': 'Isa', 'je': 'Jer', 'lm': 'Lam',
  'ez': 'Ezek', 'dn': 'Dan', 'os': 'Hos', 'jl': 'Joel', 'am': 'Amos',
  'ob': 'Obad', 'jn': 'Jonah', 'mi': 'Mic', 'na': 'Nah', 'hb': 'Hab',
  'so': 'Zeph', 'ag': 'Hag', 'za': 'Zech', 'ml': 'Mal',
};

/// Carte d'une entrée Strong (partagée par les onglets Strong/Concordance).
Widget _carteStrong(BuildContext context, EntreeStrongModel e) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.pourpre,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.orFonce.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.or,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e.numero,
                style: const TextStyle(
                    color: AppColors.nuit,
                    fontWeight: FontWeight.w900,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                e.lemma ?? '',
                style: const TextStyle(
                    color: AppColors.or,
                    fontSize: 21,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if ((e.translit ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${e.estHebreu ? 'Translittération' : 'Translit.'} : ${e.translit}',
            style: const TextStyle(color: AppColors.orPastel, fontSize: 13),
          ),
        ],
        if ((e.pron ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Prononciation : ${e.pron}',
              style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 12.5)),
        ],
        if ((e.derivation ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Étymologie',
              style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
          const SizedBox(height: 3),
          Text(e.derivation!,
              style: const TextStyle(
                  color: AppColors.texte, height: 1.45, fontSize: 13.5)),
        ],
        if ((e.definition ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Définition Strong',
              style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
          const SizedBox(height: 3),
          Text(e.definition!,
              style: const TextStyle(
                  color: AppColors.texte, height: 1.45, fontSize: 13.5)),
        ],
        if ((e.kjvDef ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Rendu KJV',
              style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
          const SizedBox(height: 3),
          Text(e.kjvDef!,
              style: const TextStyle(
                  color: AppColors.texteSecondaire,
                  height: 1.45,
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
        ],
      ],
    ),
  );
}

// ── LEXIQUE STRONG ─────────────────────────────────────────────────────

class _OngletStrong extends StatefulWidget {
  const _OngletStrong();

  @override
  State<_OngletStrong> createState() => _OngletStrongState();
}

class _OngletStrongState extends State<_OngletStrong> {
  final _repo = BibleRepository();
  final _controleur = TextEditingController(text: 'H430');
  Future<EntreeStrongModel>? _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.strong('H430');
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _chercher() {
    final numero = _controleur.text.trim().toUpperCase();
    if (numero.isEmpty) return;
    setState(() => _future = _repo.strong(numero));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controleur,
                  style: const TextStyle(color: AppColors.texte),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _chercher(),
                  decoration: InputDecoration(
                    hintText: 'H430, G26…',
                    hintStyle: const TextStyle(color: AppColors.texteEteint),
                    prefixIcon: const Icon(Icons.tag, color: AppColors.or),
                    filled: true,
                    fillColor: AppColors.pourpre,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit,
                ),
                onPressed: _chercher,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Chercher'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<EntreeStrongModel>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.or));
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.texteSecondaire),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  _carteStrong(context, snap.data!),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'H = hébreu (Ancien Testament) · G = grec (Nouveau Testament). '
                      'Exemples : H430 Elohim, H3068 YHWH, G26 agapè.',
                      style: const TextStyle(
                          color: AppColors.texteEteint,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── TEXTE HÉBRAÏQUE (MORPHHB — interlinéaire) ──────────────────────────

class _OngletHebreu extends ConsumerStatefulWidget {
  const _OngletHebreu();

  @override
  ConsumerState<_OngletHebreu> createState() => _OngletHebreuState();
}

class _OngletHebreuState extends ConsumerState<_OngletHebreu> {
  final _repo = BibleRepository();
  String _livreId = 'gn';
  int _chapitre = 1;
  int _verset = 1;
  Future<VersetHebreuModel>? _future;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    final oshb = kOshbParLivreId[_livreId]!;
    setState(() => _future = _repo.hebreu(oshb, _chapitre, _verset));
  }

  @override
  Widget build(BuildContext context) {
    final livre = livreBibleParId(_livreId);
    return Column(
      children: [
        Container(
          color: AppColors.pourpre,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _choisirLivre,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.article_outlined,
                            size: 17, color: AppColors.or),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${livre?.nom ?? _livreId} $_chapitre:$_verset',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.texte,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.expand_more,
                            size: 18, color: AppColors.texteSecondaire),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.orPastel),
                onPressed: (_chapitre > 1 || _verset > 1)
                    ? () {
                        if (_verset > 1) {
                          _verset--;
                        } else {
                          _chapitre--;
                          _verset = 1;
                        }
                        _charger();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.orPastel),
                onPressed: () {
                  _verset++;
                  _charger();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<VersetHebreuModel>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.or));
              }
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snap.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.texteSecondaire),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ce verset n\u2019est pas dans le corpus morphologique (AT).',
                        style: TextStyle(
                            color: AppColors.texteEteint, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              final v = snap.data!;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Interlinéaire hébraïque — ${livre?.nom} $_chapitre:$_verset',
                    style: const TextStyle(
                        color: AppColors.or,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in v.mots)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _motVersStrong(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.nuitClair,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.orFonce
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(m.mot,
                                    style: const TextStyle(
                                        color: AppColors.texte,
                                        fontSize: 16,
                                        height: 1.2)),
                                const SizedBox(height: 3),
                                Text(
                                  m.lemme,
                                  style: const TextStyle(
                                      color: AppColors.orPastel, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Touchez un mot pour l\u2019ouvrir dans le lexique Strong.',
                    style: TextStyle(
                        color: AppColors.texteEteint,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Extrait un numéro Strong du lemme (ex. 'H430/b') → affiche la fiche
  /// Strong dans une feuille modale (et bascule sur l'onglet Strong).
  void _motVersStrong(MotHebreuModel m) {
    final match =
        RegExp(r'^[Hh](\d+)').firstMatch(m.lemme) ??
            RegExp(r'/([Hh]?\d+)').firstMatch(m.lemme);
    if (match != null) {
      final numero = 'H${match.group(1)!.replaceAll(RegExp(r'[^0-9]'), '')}';
      if (numero.length > 1) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.pourpre,
          builder: (sheetContext) => FutureBuilder<EntreeStrongModel>(
            future: _repo.strong(numero),
            builder: (context, snap) => snap.connectionState ==
                    ConnectionState.waiting
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppColors.or),
                    ),
                  )
                : snap.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(snap.error.toString(),
                            style: const TextStyle(
                                color: AppColors.texteSecondaire)),
                      )
                    : ListView(shrinkWrap: true, children: [_carteStrong(context, snap.data!)]),
          ),
        );
        return;
      }
    }
    // Repli : basculer sur l'onglet Strong pour une saisie manuelle.
    DefaultTabController.of(context).animateTo(2);
  }

  void _choisirLivre() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (sheetContext, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Texte hébraïque — choisir un livre (AT)',
                  style: TextStyle(
                      color: AppColors.or,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in kOshbParLivreId.keys)
                  ActionChip(
                    backgroundColor: _livreId == id
                        ? AppColors.or.withValues(alpha: 0.25)
                        : AppColors.nuitClair,
                    label: Text(
                      livreBibleParId(id)?.nom ?? id,
                      style: TextStyle(
                          color:
                              _livreId == id ? AppColors.or : AppColors.texte,
                          fontSize: 12.5),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _livreId = id;
                      _chapitre = 1;
                      _verset = 1;
                      _charger();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── PESHITTA ARAMÉENNE ─────────────────────────────────────────────────

class _OngletPeshitta extends StatefulWidget {
  const _OngletPeshitta();

  @override
  State<_OngletPeshitta> createState() => _OngletPeshittaState();
}

class _OngletPeshittaState extends State<_OngletPeshitta> {
  final _repo = BibleRepository();
  String _livre = 'Genesis';
  int _chapitre = 1;
  Future<ChapitrePeshittaModel>? _future;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    setState(() => _future = _repo.peshitta(_livre, _chapitre));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.pourpre,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _choisirLivre,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.language, size: 17, color: AppColors.or),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_livre $_chapitre',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.texte,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.expand_more,
                            size: 18, color: AppColors.texteSecondaire),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Chapitre précédent',
                icon: const Icon(Icons.chevron_left, color: AppColors.orPastel),
                onPressed: _chapitre > 1
                    ? () {
                        _chapitre--;
                        _charger();
                      }
                    : null,
              ),
              IconButton(
                tooltip: 'Chapitre suivant',
                icon: const Icon(Icons.chevron_right, color: AppColors.orPastel),
                onPressed: () {
                  _chapitre++;
                  _charger();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<ChapitrePeshittaModel>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.or));
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.texteSecondaire),
                  ),
                );
              }
              final c = snap.data!;
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: c.versets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final v = c.versets[i];
                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${v.numero} ',
                          style: const TextStyle(
                              color: AppColors.or,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                        TextSpan(
                          text: v.texte,
                          style: const TextStyle(
                              color: AppColors.texte,
                              height: 1.9,
                              fontSize: 16),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _choisirLivre() {
    final livresPeshitta = [
      'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
      'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
      '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
      'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs', 'Isaiah',
      'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
      'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
      'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
      'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
      'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
      '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
      'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
      'Jude', 'Revelation',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pourpre,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (sheetContext, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Peshitta araméenne — choisir un livre',
                  style: TextStyle(
                      color: AppColors.or,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in livresPeshitta)
                  ActionChip(
                    backgroundColor: _livre == l
                        ? AppColors.or.withValues(alpha: 0.25)
                        : AppColors.nuitClair,
                    label: Text(
                      l,
                      style: TextStyle(
                          color: _livre == l ? AppColors.or : AppColors.texte,
                          fontSize: 12.5),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _livre = l;
                      _chapitre = 1;
                      _charger();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── CONCORDANCE STRONG ─────────────────────────────────────────────────

class _OngletConcordance extends StatefulWidget {
  const _OngletConcordance();

  @override
  State<_OngletConcordance> createState() => _OngletConcordanceState();
}

class _OngletConcordanceState extends State<_OngletConcordance> {
  final _repo = BibleRepository();
  final _controleur = TextEditingController(text: 'H430');
  Future<ConcordanceModel>? _future;

  @override
  void initState() {
    super.initState();
    _chercher();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _chercher() {
    final numero = _controleur.text.trim().toUpperCase();
    if (numero.isEmpty) return;
    setState(() => _future = _repo.concordance(numero));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controleur,
                  style: const TextStyle(color: AppColors.texte),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _chercher(),
                  decoration: InputDecoration(
                    hintText: 'Numéro hébreu (H…)',
                    hintStyle: const TextStyle(color: AppColors.texteEteint),
                    prefixIcon:
                        const Icon(Icons.shield_outlined, color: AppColors.or),
                    filled: true,
                    fillColor: AppColors.pourpre,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit,
                ),
                onPressed: _chercher,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Lister'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<ConcordanceModel>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.or));
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.texteSecondaire),
                  ),
                );
              }
              final c = snap.data!;
              return ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  if (c.strong != null) _carteStrong(context, c.strong!),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${c.nombreVersets} occurrence(s) dans l\u2019Ancien Testament',
                      style: const TextStyle(
                          color: AppColors.orPastel,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  for (final occ in c.versets)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.book, size: 18, color: AppColors.or),
                      title: Text(
                        '${livreBibleParId(occ.livreId)?.nom ?? occ.livre} ${occ.chapitre}:${occ.verset}',
                        style: const TextStyle(
                            color: AppColors.texte,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5),
                      ),
                      subtitle: Text(
                        occ.mots.map((m) => m.mot).join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.texteSecondaire, fontSize: 12.5),
                        textDirection: TextDirection.rtl,
                      ),
                      onTap: () {
                        // Ouvre le verset dans l'onglet Hébreu interlinéaire.
                        DefaultTabController.of(context).animateTo(3);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── COMPARATIF (verset parallèle dans les 6 versions) ──────────────────

class _OngletComparatif extends ConsumerStatefulWidget {
  const _OngletComparatif();

  @override
  ConsumerState<_OngletComparatif> createState() => _OngletComparatifState();
}

class _OngletComparatifState extends ConsumerState<_OngletComparatif> {
  final _repo = BibleRepository();
  final _versetCtrl = TextEditingController(text: '16');
  Future<List<({String code, String nom, VersetBibleModel? verset})>>? _future;

  static const _versions = [
    ('fr-apee', 'Bible de l\u2019Épée'),
    ('en-kjv', 'King James Version'),
    ('en-bbe', 'Basic English'),
    ('es-rvr', 'Reina Valera'),
    ('pt-acf', 'Almeida Corrigida'),
    ('ar-svd', 'Arabic Bible'),
  ];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _versetCtrl.dispose();
    super.dispose();
  }

  void _charger() {
    final etat = ref.read(bibleProvider);
    final verset = int.tryParse(_versetCtrl.text.trim()) ?? 1;
    setState(() {
      _future = Future.wait(_versions.map((v) async {
        final res = await _repo.versetParallele(
            v.$1, etat.livreId, etat.chapitre, verset);
        return (code: v.$1, nom: v.$2, verset: res);
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(bibleProvider);
    final livre = livreBibleParId(etat.livreId);
    return Column(
      children: [
        Container(
          color: AppColors.pourpre,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${livre?.nom ?? etat.livreId} ${etat.chapitre} — verset :',
                  style: const TextStyle(
                      color: AppColors.texte,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5),
                ),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _versetCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.or, fontSize: 13.5),
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _charger(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.nuitClair,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit,
                ),
                onPressed: _charger,
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('Comparer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<
              List<({String code, String nom, VersetBibleModel? verset})>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.or));
              }
              if (snap.hasError) {
                return Center(
                  child: Text(snap.error.toString(),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppColors.texteSecondaire)),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  for (final v in snap.data!)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pourpre,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.orFonce.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.nom,
                            style: const TextStyle(
                                color: AppColors.or,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.verset?.texte ??
                                '— verset non disponible dans cette version —',
                            style: TextStyle(
                                color: v.verset != null
                                    ? AppColors.texte
                                    : AppColors.texteEteint,
                                height: 1.5,
                                fontSize: 14,
                                fontStyle: v.verset != null
                                    ? FontStyle.normal
                                    : FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

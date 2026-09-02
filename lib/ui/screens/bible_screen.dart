/// ⭐ ÉCRAN DÉDIÉ — Bible (parité web V2.6 / BibleWorkspace) :
///
///   • 6 versions (fr-apee, en-kjv, en-bbe, es-rvr, pt-acf, ar-svd) ;
///   • navigation 66 livres AT/NT + chapitres, chapitre ◀ ▶ ;
///   • versets numérotés — tap → Marque-page / Partager dans un chat
///     (message VERSE, même format que le web) ;
///   • recherche plein texte de la version courante ;
///   • marque-pages persistés dans la base du projet mère (partagés
///     avec le web : marquer sur mobile = retrouver sur le web).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/bible_model.dart';
import '../../state/bible_controller.dart';
import '../../state/conversations_controller.dart';

class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(bibleProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.nuit,
        appBar: AppBar(
          title: const Text('Bible'),
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
            indicatorColor: AppColors.or,
            labelColor: AppColors.or,
            unselectedLabelColor: AppColors.texteSecondaire,
            tabs: [
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Lecture'),
              Tab(icon: Icon(Icons.search), text: 'Recherche'),
              Tab(icon: Icon(Icons.bookmark_border), text: 'Marque-pages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VueLecture(etat: etat),
            const _VueRecherche(),
            const _VueMarquePages(),
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
            color: AppColors.or.withOpacity(0.12),
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
                      ? AppColors.or.withOpacity(0.25)
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

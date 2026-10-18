/// ⭐ V2.0 — ANNONCES DU MINISTÈRE (miroir de la page /annonces, V3.67 web).
///
/// La voix officielle du Mouvement Christ Libère : lives programmés,
/// événements et communiqués publiés par le secrétariat (back-office
/// staff). Les publications PLANIFIÉES basculent automatiquement à leur
/// échéance côté serveur (même comportement que la page publique).
///
/// HORS-LIGNE : annonces depuis la base SQLite locale — les urgence en
/// tête (même tri que le web : urgence > autres catégories, date décroissante).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/markdown_texte.dart';
import '../../data/models/contenu_models.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

class AnnoncesMinistereScreen extends ConsumerWidget {
  const AnnoncesMinistereScreen({super.key});

  static const _iconesCategories = {
    'generale': Icons.campaign_outlined,
    'live': Icons.sensors,
    'evenement': Icons.calendar_month_outlined,
    'urgence': Icons.warning_amber_rounded,
  };

  static const _libellesCategories = {
    'generale': 'Communiqué',
    'live': 'Live',
    'evenement': 'Événement',
    'urgence': 'URGENT',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageAnnonces(enfant: EtatPremiereSync());
    }

    // Tri : urgence en tête (comme le web), puis date décroissante.
    final annonces = [...contenu.annonces]..sort((a, b) {
        if (a.estUrgente != b.estUrgente) return a.estUrgente ? -1 : 1;
        return b.publieLe.compareTo(a.publieLe);
      });

    return _PageAnnonces(
      enfant: Column(
        children: [
          HeroEnTete(hero: contenu.hero('annonces'), hauteur: 150),
          Expanded(
            child: annonces.isEmpty
                ? const EtatSectionVide(
                    message:
                        'Aucune annonce publiée pour l\'instant — les '
                        'communications officielles du secrétariat '
                        'apparaîtront ici.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    itemCount: annonces.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CarteAnnonce(annonce: annonces[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CarteAnnonce extends StatelessWidget {
  final AnnonceMinistereModele annonce;

  const _CarteAnnonce({required this.annonce});

  @override
  Widget build(BuildContext context) {
    final icone = AnnoncesMinistereScreen._iconesCategories[annonce.categorie] ??
        Icons.campaign_outlined;
    final libelle =
        AnnoncesMinistereScreen._libellesCategories[annonce.categorie] ?? 'Communiqué';
    final date = DateTime.tryParse(annonce.publieLe);

    return CarteContenu(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icone,
                size: 17,
                color: annonce.estUrgente ? AppColors.danger : AppColors.or,
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (annonce.estUrgente ? AppColors.danger : AppColors.or)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  libelle,
                  style: TextStyle(
                    color: annonce.estUrgente ? AppColors.danger : AppColors.orPastel,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              if (date != null)
                Text(
                  Formatters.jour(date),
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            annonce.titre,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 7),
          // ⭐ V2.3 — contenu au rendu markdown professionnel (gras,
          // italique, titres, listes — plus d'astérisques visibles).
          TexteMarkdown(annonce.contenu, tailleCorps: 13.5),
        ],
      ),
    );
  }
}

/// Scaffold commun.
class _PageAnnonces extends StatelessWidget {
  final Widget enfant;

  const _PageAnnonces({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Annonces du ministère',
          style: TextStyle(color: AppColors.texte, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}

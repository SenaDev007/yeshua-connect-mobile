/// ⭐ V2.0 — SERVITEURS : fiche complète d'Afrika et du Pasteur Kongo.
///
/// Reproduit les pages /afrika et /pasteur-kongo du site : photo, rôle,
/// biographie (hero paramétrable back-office) et FRISE CHRONOLOGIQUE
/// (module Biographies du back-office — jalons avec versets et photos).
///
/// HORS-LIGNE : tout vient de la base SQLite locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/markdown_texte.dart';
import '../../data/models/contenu_models.dart';
import '../../state/contenu_controller.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/contenu_widgets.dart';

class ServiteurScreen extends ConsumerWidget {
  final String code; // "afrika" | "kongo"

  const ServiteurScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenu = ref.watch(contenuProvider);
    final serviteur = contenu.serviteurs.where((s) => s.code == code).firstOrNull;

    if (contenu.jamaisSynchronise) {
      return const _PageServiteur(enfant: EtatPremiereSync());
    }
    if (serviteur == null) {
      return const _PageServiteur(
        enfant: EtatSectionVide(message: 'Ce serviteur n\'est pas encore publié.'),
      );
    }

    final hero = contenu.hero(code == 'kongo' ? 'pasteur-kongo' : code);

    return _PageServiteur(
      enfant: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          HeroEnTete(hero: hero),
          const SizedBox(height: 20),
          // ── Carte d'identité ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CarteContenu(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 104,
                      height: 104,
                      child: ImageUniverselle(
                        url: resoudreUrl(serviteur.photoEffective),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviteur.nomComplet,
                          style: const TextStyle(
                            color: AppColors.or,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serviteur.role,
                          style: const TextStyle(
                            color: AppColors.texteSecondaire,
                            fontSize: 13,
                          ),
                        ),
                        if (serviteur.ville.isNotEmpty || serviteur.pays.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: AppColors.texteEteint),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  [
                                    if (serviteur.ville.isNotEmpty) serviteur.ville,
                                    if (serviteur.pays.isNotEmpty) serviteur.pays,
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: AppColors.texteEteint,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // ── Biographie ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CarteContenu(
              padding: const EdgeInsets.all(18),
              // ⭐ V2.3 — biographie au rendu markdown professionnel
              // (gras/italique — plus d'astérisques visibles).
              child: TexteMarkdown(serviteur.bio, tailleCorps: 14),
            ),
          ),
          // ── Frise chronologique ──
          if (serviteur.biographies.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'PARCOURS',
                style: TextStyle(
                  color: AppColors.or,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...serviteur.biographies.map((j) => _Jalon(jalon: j)),
          ],
        ],
      ),
    );
  }
}

/// Un jalon de la frise chronologique (même disposition verticale dorée
/// que la frise publique du site).
class _Jalon extends StatelessWidget {
  final JalonBiographique jalon;

  const _Jalon({required this.jalon});

  @override
  Widget build(BuildContext context) {
    final photo = resoudreUrl(jalon.photoUrl);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Colonne frise : pastille + trait ──
          SizedBox(
            width: 54,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.or,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.nuit, width: 2.5),
                  ),
                ),
                Container(width: 2, color: AppColors.or.withValues(alpha: 0.35)),
              ],
            ),
          ),
          // ── Carte du jalon ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 14),
              child: CarteContenu(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jalon.date,
                      style: const TextStyle(
                        color: AppColors.orPastel,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jalon.titre,
                      style: const TextStyle(
                        color: AppColors.texte,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (jalon.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      // ⭐ V2.3 — description au rendu markdown.
                      TexteMarkdown(jalon.description, tailleCorps: 13),
                    ],
                    if (jalon.versetTexte.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.nuit.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '« ${jalon.versetTexte} »',
                              style: const TextStyle(
                                color: AppColors.orPastel,
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                            if (jalon.versetRef.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  jalon.versetRef,
                                  style: const TextStyle(
                                    color: AppColors.texteEteint,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (photo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ImageUniverselle(
                          url: photo,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold commun des pages serviteur.
class _PageServiteur extends StatelessWidget {
  final Widget enfant;

  const _PageServiteur({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Christ ', style: TextStyle(color: AppColors.or)),
              TextSpan(text: 'Libère', style: TextStyle(color: AppColors.texte)),
            ],
          ),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}

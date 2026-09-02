/// ⭐ ÉCRAN DÉDIÉ — Calendrier biblique + Shofar (parité web V3.6 :
/// CalendarWorkspace + ShofarNotifier) :
///
///   • prochain événement avec COMPTE À REBOURS en direct ;
///   • liste des prochains événements (Shabbats + solennités, jalons
///     J-7 / J-3 / J-24 h, entrée/sortie au coucher du soleil) ;
///   • écoute du son du shofar (même fichier que le web) ;
///   • annonce de la prochaine solennité dans un chat (texte identique) ;
///   • fêtes de l'Éternel par année biblique (3 années, navigation ◀ ▶).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/calendar_model.dart';
import '../../state/calendar_controller.dart';
import '../../state/conversations_controller.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  Timer? _ticker;
  bool _annonceEnvoyee = false;

  @override
  void initState() {
    super.initState();
    // Compte à rebours rafraîchi chaque seconde (comme le web).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _compteARebours(DateTime cible) {
    var reste = cible.difference(DateTime.now());
    if (reste.isNegative) return 'en cours';
    final jours = reste.inDays;
    final heures = reste.inHours % 24;
    final minutes = reste.inMinutes % 60;
    final secondes = reste.inSeconds % 60;
    if (jours > 0) return 'dans $jours j $heures h';
    if (heures > 0) return 'dans $heures h $minutes min';
    return 'dans $minutes min ${secondes.toString().padLeft(2, '0')} s';
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(calendarProvider);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        title: const Text('Calendrier biblique'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh, color: AppColors.orPastel),
            onPressed: () => ref.read(calendarProvider.notifier).charger(),
          ),
        ],
      ),
      body: etat.chargement && etat.evenements.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.or))
          : etat.erreur != null && etat.evenements.isEmpty
              ? _vueErreur(etat.erreur!)
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (etat.prochainEvenement != null) ...[
                      _carteProchain(context, etat.prochainEvenement!, etat),
                      const SizedBox(height: 18),
                    ],
                    const _TitreSection('Prochains événements'),
                    const SizedBox(height: 8),
                    for (final e in etat.prochainsEvenements.skip(1)) ...[
                      _carteEvenement(e),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 18),
                    _sectionAnnees(etat),
                  ],
                ),
    );
  }

  Widget _vueErreur(String erreur) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.danger, size: 44),
              const SizedBox(height: 12),
              Text(
                erreur,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texteSecondaire),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.read(calendarProvider.notifier).charger(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );

  // ─── Carte « prochain événement » + actions Shofar / Annonce ────────

  Widget _carteProchain(BuildContext context, EvenementShofarModel e, CalendarState etat) {
    final formatHeure = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.or.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                e.estFete ? Icons.celebration_outlined : Icons.brightness_7,
                color: _couleurHex(e.couleur),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${e.titre}${e.titreHebreu != null ? ' · ${e.titreHebreu}' : ''}',
                  style: const TextStyle(
                    color: AppColors.or,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '📆 ${_compteARebours(e.entree)} — entrée ${DateFormat('EEEE d MMMM', 'fr_FR').format(e.entree)} à ${formatHeure.format(e.entree)} (coucher du soleil)',
            style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 13.5),
          ),
          if (e.dateBiblique != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Date biblique : ${e.dateBiblique}',
                style: const TextStyle(color: AppColors.texteEteint, fontSize: 13),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              // 🔊 Son du shofar (même fichier que le web).
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.or,
                    side: const BorderSide(color: AppColors.orFonce),
                  ),
                  onPressed: () {
                    final controller = ref.read(calendarProvider.notifier);
                    if (etat.shofarEnCours) {
                      controller.arreterShofar();
                    } else {
                      controller.jouerShofar();
                    }
                  },
                  icon: Icon(
                    etat.shofarEnCours ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    size: 18,
                  ),
                  label: Text(etat.shofarEnCours ? 'Arrêter' : '🔊 Shofar'),
                ),
              ),
              const SizedBox(width: 10),
              // 📯 Annoncer dans le chat (une seule fois — comme le web).
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.or,
                    foregroundColor: AppColors.nuit,
                  ),
                  onPressed: _annonceEnvoyee ? null : () => _annoncer(context, e),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Annoncer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _annoncer(BuildContext context, EvenementShofarModel e) {
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
                'Annoncer dans…',
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
                title: Text(conv.displayName, style: const TextStyle(color: AppColors.texte)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    await ref
                        .read(calendarProvider.notifier)
                        .partagerAnnonce(e, conv.id);
                    setState(() => _annonceEnvoyee = true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Annonce partagée dans ${conv.displayName}'),
                        ),
                      );
                    }
                  } catch (err) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err.toString())),
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

  // ─── Carte d'un événement ───────────────────────────────────────────

  Widget _carteEvenement(EvenementShofarModel e) {
    final formatHeure = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.pourpreClair.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _couleurHex(e.couleur), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${e.titre}${e.titreHebreu != null ? ' · ${e.titreHebreu}' : ''}',
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _compteARebours(e.entree),
                style: const TextStyle(color: AppColors.orPastel, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Entrée ${DateFormat('d MMM', 'fr_FR').format(e.entree)} ${formatHeure.format(e.entree)} · '
            'sortie ${DateFormat('d MMM', 'fr_FR').format(e.sortie)} ${formatHeure.format(e.sortie)}'
            '${e.dureeJours > 1 ? ' · ${e.dureeJours} jours' : ''}',
            style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 12.5),
          ),
          if (e.dateBiblique != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                e.dateBiblique!,
                style: const TextStyle(color: AppColors.texteEteint, fontSize: 12),
              ),
            ),
          if (e.travailInterdit)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '· Sainte convocation — travail interdit ·',
                style: TextStyle(color: AppColors.or, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Fêtes de l'Éternel par année ───────────────────────────────────

  Widget _sectionAnnees(CalendarState etat) {
    final annee = etat.anneeAffichee;
    if (annee == null) return const SizedBox.shrink();
    final fetesTriees = [...annee.fetes]..sort((a, b) => a.dateGregorienne.compareTo(b.dateGregorienne));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.orPastel),
              onPressed:
                  etat.indexAnneeAffichee > 0 ? ref.read(calendarProvider.notifier).anneePrecedente : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    annee.libelle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.or,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${DateFormat('yyyy', 'fr_FR').format(annee.debut)}–${DateFormat('yyyy', 'fr_FR').format(annee.fin)} · ${annee.nombreJours} jours',
                    style: const TextStyle(color: AppColors.texteEteint, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.orPastel),
              onPressed: etat.indexAnneeAffichee < etat.annees.length - 1
                  ? ref.read(calendarProvider.notifier).anneeSuivante
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final fete in fetesTriees) ...[
          _carteFete(fete),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _carteFete(FeteModel fete) {
    final passee = fete.estPassee;
    return Opacity(
      opacity: passee ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.pourpreClair.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: _couleurHex(fete.couleur), width: 3.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fete.nomFr}${fete.nomHebrew != null ? ' · ${fete.nomHebrew}' : ''}',
                    style: const TextStyle(
                      color: AppColors.texte,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${fete.dateBiblique} — ${DateFormat('d MMMM yyyy', 'fr_FR').format(fete.dateGregorienne)}'
                    '${fete.dureeJours > 1 ? ' · ${fete.dureeJours} jours' : ''}',
                    style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 12.5),
                  ),
                  Text(
                    fete.referenceEcritures,
                    style: const TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            fete.estPassee
                ? const Text(
                    'passée',
                    style: TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.or.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fete.joursRestants > 1 ? 'J-${fete.joursRestants}' : 'J-1',
                      style: const TextStyle(
                        color: AppColors.or,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Color _couleurHex(String hex) {
    final propre = hex.replaceFirst('#', '');
    if (propre.length != 6) return AppColors.or;
    final valeur = int.tryParse('FF$propre', radix: 16);
    return valeur == null ? AppColors.or : Color(valeur);
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Text(
        texte,
        style: const TextStyle(
          color: AppColors.texteSecondaire,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.6,
        ),
      );
}

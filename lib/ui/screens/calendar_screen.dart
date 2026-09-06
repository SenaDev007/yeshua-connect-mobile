/// ⭐ ÉCRAN DÉDIÉ — Calendrier biblique + Shofar (parité web V3.6 :
/// CalendarWorkspace + ShofarNotifier) :
///
///   • VUE AUJOURD'HUI : prochain événement avec COMPTE À REBOURS en
///     direct, liste des prochains événements (Shabbats + solennités,
///     jalons J-7 / J-3 / J-24 h, entrée/sortie au coucher du soleil) ;
///   • ⭐ V1.7 — VUE MENSUELLE : la GRILLE DU MOIS BIBLIQUE comme sur le
///     web (vue-mensuelle.tsx) — 12 mois × 30 jours, Shabbats dorés,
///     fêtes surlignées, date grégorienne en écho, navigation ◀ ▶ ;
///   • VUE ANNÉES : fêtes de l'Éternel par année biblique (3 années) ;
///   • écoute du son du shofar (même fichier que le web) ;
///   • annonce de la prochaine solennité dans un chat (texte identique).
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

  // ⭐ V1.7 — Vue mensuelle : mois biblique affiché (1-12).
  int _moisCourant = 1;

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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: const TabBar(
            indicatorColor: AppColors.or,
            labelColor: AppColors.or,
            unselectedLabelColor: AppColors.texteSecondaire,
            tabs: [
              Tab(icon: Icon(Icons.today_outlined), text: 'Aujourd\'hui'),
              Tab(icon: Icon(Icons.calendar_view_month_outlined), text: 'Mois'),
              Tab(icon: Icon(Icons.calendar_today_outlined), text: 'Années'),
            ],
          ),
        ),
        body: etat.chargement && etat.evenements.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.or))
            : etat.erreur != null && etat.evenements.isEmpty
                ? _vueErreur(etat.erreur!)
                : TabBarView(
                    children: [
                      _vueAujourdhui(etat),
                      _vueMensuelle(etat),
                      _vueAnnees(etat),
                    ],
                  ),
      ),
    );
  }

  /// ─── Vue 1 : aujourd'hui + prochains événements (contenu initial) ───
  Widget _vueAujourdhui(CalendarState etat) => ListView(
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
        ],
      );

  /// ─── Vue 2 : ⭐ V1.7 — GRILLE DU MOIS BIBLIQUE (comme vue-mensuelle
  /// web) : 7 colonnes (1er jour → Shabbat), Shabbats dorés, fêtes
  /// surlignées, jour courant encadré, navigation ◀ ▶ + fêtes du mois.
  Widget _vueMensuelle(CalendarState etat) {
    final annee = etat.anneeAffichee;
    if (annee == null || annee.jours.isEmpty) {
      return const Center(
        child: Text(
          'Vue mensuelle indisponible sur ce backend.',
          style: TextStyle(color: AppColors.texteSecondaire),
        ),
      );
    }

    // Mois courant = celui qui contient aujourd'hui (init une seule fois).
    if (_moisInitialise == false) {
      _moisInitialise = true;
      try {
        final aujourdhui = DateTime.now();
        final j = annee.jours.firstWhere(
          (x) =>
              x.dateGregorienne.year == aujourdhui.year &&
              x.dateGregorienne.month == aujourdhui.month &&
              x.dateGregorienne.day == aujourdhui.day,
        );
        _moisCourant = j.mois;
      } catch (_) {
        _moisCourant = 1;
      }
    }

    final joursMois = annee.joursDuMois(_moisCourant);
    if (joursMois.isEmpty) {
      _moisCourant = 1;
    }
    final jours = annee.joursDuMois(_moisCourant);
    final nomMois = jours.isNotEmpty ? jours.first.nomMois : '';

    // Map jourDuMois → fête (dateBiblique « 14 Aviv » → jour + mois).
    final feteParJour = <int, FeteModel>{};
    for (final fete in annee.fetes) {
      final parts = fete.dateBiblique.split(' ');
      if (parts.length < 2) continue;
      final numero = int.tryParse(parts[0]);
      final nom = parts.sublist(1).join(' ').trim();
      if (numero != null && nom == nomMois) feteParJour[numero] = fete;
    }

    final aujourdhui = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── En-tête mois ◀ ▶ ──
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.orPastel),
              onPressed: _moisCourant > 1
                  ? () => setState(() => _moisCourant--)
                  : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    nomMois,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.or,
                        fontWeight: FontWeight.w800,
                        fontSize: 17),
                  ),
                  Text(
                    'Mois $_moisCourant · ${jours.length} jours · ${annee.libelle}',
                    style: const TextStyle(
                        color: AppColors.texteEteint, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.orPastel),
              onPressed: _moisCourant < 12
                  ? () => setState(() => _moisCourant++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── En-tête des 7 jours de la semaine biblique ──
        Row(
          children: [
            for (final j in const ['J1', 'J2', 'J3', 'J4', 'J5', 'J6', 'Shabbat'])
              Expanded(
                child: Center(
                  child: Text(
                    j,
                    style: TextStyle(
                        color: j == 'Shabbat'
                            ? AppColors.or
                            : AppColors.texteSecondaire,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Grille ──
        Table(
          border: TableBorder.all(
              color: AppColors.nuitClair.withValues(alpha: 0.6), width: 0.7),
          children: [
            for (var ligne = 0; ligne < (jours.length / 7).ceil(); ligne++)
              TableRow(
                children: [
                  for (var col = 0; col < 7; col++)
                    _celluleJour(
                      joursMois: jours,
                      index: ligne * 7 + col,
                      feteParJour: feteParJour,
                      aujourdhui: aujourdhui,
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Fêtes du mois ──
        if (feteParJour.isNotEmpty) ...[
          const _TitreSection('Fêtes du mois'),
          const SizedBox(height: 8),
          for (final f in feteParJour.values) ...[
            _carteFete(f),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  bool _moisInitialise = false;

  /// Une cellule du mois : numéro biblique + écho grégorien + marqueurs
  /// (Shabbat doré, fête colorée, jour courant encadré or).
  Widget _celluleJour({
    required List<JourBibliqueModel> joursMois,
    required int index,
    required Map<int, FeteModel> feteParJour,
    required DateTime aujourdhui,
  }) {
    if (index >= joursMois.length) {
      return const SizedBox(height: 52);
    }
    final j = joursMois[index];
    final fete = feteParJour[j.jourDuMois];
    final estAujourdhui = j.dateGregorienne.year == aujourdhui.year &&
        j.dateGregorienne.month == aujourdhui.month &&
        j.dateGregorienne.day == aujourdhui.day;

    Color? fond;
    Color bord = Colors.transparent;
    Color texte = AppColors.texte;
    if (j.estShabbat) {
      fond = AppColors.or.withValues(alpha: 0.14);
      texte = AppColors.orPastel;
    }
    if (fete != null) {
      fond = _couleurHex(fete.couleur).withValues(alpha: 0.30);
    }
    if (estAujourdhui) bord = AppColors.or;

    return TableCell(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: fond,
          border: Border.all(
              color: estAujourdhui ? bord : Colors.transparent, width: 1.8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${j.jourDuMois}',
              style: TextStyle(
                  color: texte,
                  fontSize: 14,
                  fontWeight: j.estShabbat || fete != null
                      ? FontWeight.w800
                      : FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              '${j.dateGregorienne.day}/${j.dateGregorienne.month}',
              style: TextStyle(
                  color: AppColors.texteEteint, fontSize: 8.5),
            ),
            if (fete != null)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: _couleurHex(fete.couleur),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ─── Vue 3 : fêtes de l'Éternel par année ───
  Widget _vueAnnees(CalendarState etat) => ListView(
        padding: const EdgeInsets.all(14),
        children: [_sectionAnnees(etat)],
      );

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

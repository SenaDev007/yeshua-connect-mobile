/// ⭐ État + actions du calendrier biblique mobile (miroir du
/// CalendarWorkspace + ShofarNotifier web) :
///   • prochains événements (Shabbats + solennités + jalons J-7/3/24 h) ;
///   • 3 années bibliques (fêtes de l'Éternel) ;
///   • écoute du SON DU SHOFAR (même fichier que le web : /sounds/shofar.mp3
///     servi par le backend partagé) ;
///   • partage d'annonce dans une conversation — TEXTE IDENTIQUE au web.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../data/models/calendar_model.dart';
import '../data/repositories/calendar_repository.dart';
import '../data/repositories/messages_repository.dart';

class CalendarState {
  final bool chargement;
  final String? erreur;

  final DateTime maintenant;
  final int anneeBiblique;
  final List<EvenementShofarModel> evenements;
  final List<AnneeBibliqueModel> annees;

  /// Année affichée dans la section « Fêtes de l'Éternel ».
  final int indexAnneeAffichee;

  /// Le shofar est-il en cours d'écoute ?
  final bool shofarEnCours;

  const CalendarState({
    this.chargement = false,
    this.erreur,
    required this.maintenant,
    this.anneeBiblique = 0,
    this.evenements = const [],
    this.annees = const [],
    this.indexAnneeAffichee = 1,
    this.shofarEnCours = false,
  });

  CalendarState copyWith({
    bool? chargement,
    bool clearErreur = false,
    String? erreur,
    DateTime? maintenant,
    int? anneeBiblique,
    List<EvenementShofarModel>? evenements,
    List<AnneeBibliqueModel>? annees,
    int? indexAnneeAffichee,
    bool? shofarEnCours,
  }) =>
      CalendarState(
        chargement: chargement ?? this.chargement,
        erreur: clearErreur ? null : (erreur ?? this.erreur),
        maintenant: maintenant ?? this.maintenant,
        anneeBiblique: anneeBiblique ?? this.anneeBiblique,
        evenements: evenements ?? this.evenements,
        annees: annees ?? this.annees,
        indexAnneeAffichee: indexAnneeAffichee ?? this.indexAnneeAffichee,
        shofarEnCours: shofarEnCours ?? this.shofarEnCours,
      );

  /// Les 6 prochains événements à venir (même découpe que le web).
  List<EvenementShofarModel> get prochainsEvenements {
    final now = DateTime.now();
    final aVenir = evenements.where((e) => e.entree.isAfter(now)).toList();
    aVenir.sort((a, b) => a.entree.compareTo(b.entree));
    return aVenir.take(6).toList();
  }

  EvenementShofarModel? get prochainEvenement =>
      prochainsEvenements.isNotEmpty ? prochainsEvenements.first : null;

  AnneeBibliqueModel? get anneeAffichee {
    if (annees.isEmpty) return null;
    var i = indexAnneeAffichee;
    if (i < 0 || i >= annees.length) i = annees.length ~/ 2;
    return annees[i];
  }
}

class CalendarController extends Notifier<CalendarState> {
  final CalendarRepository _repo = CalendarRepository();
  final AudioPlayer _shofar = AudioPlayer();

  @override
  CalendarState build() {
    _shofar.onPlayerComplete.listen((_) {
      state = state.copyWith(shofarEnCours: false);
    });
    _shofar.onPlayerStateChanged.listen((s) {
      state = state.copyWith(shofarEnCours: s == PlayerState.playing);
    });
    charger();
    return CalendarState(maintenant: DateTime.now());
  }

  Future<void> charger() async {
    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      final donnees = await _repo.evenements();
      // Index de l'année en cours (même logique que le web : l'année qui
      // contient « maintenant »).
      var index = 1;
      final now = DateTime.now();
      for (var i = 0; i < donnees.annees.length; i++) {
        final a = donnees.annees[i];
        final finJour = a.fin.add(const Duration(days: 1));
        if (!a.debut.isAfter(now) && finJour.isAfter(now)) {
          index = i;
          break;
        }
      }
      state = state.copyWith(
        chargement: false,
        maintenant: donnees.maintenant,
        anneeBiblique: donnees.anneeBiblique,
        evenements: donnees.evenements,
        annees: donnees.annees,
        indexAnneeAffichee: index,
      );
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: e.toString());
    }
  }

  /// Navigue entre les années bibliques (◀ ▶).
  void anneePrecedente() {
    if (state.indexAnneeAffichee > 0) {
      state = state.copyWith(indexAnneeAffichee: state.indexAnneeAffichee - 1);
    }
  }

  void anneeSuivante() {
    if (state.indexAnneeAffichee < state.annees.length - 1) {
      state = state.copyWith(indexAnneeAffichee: state.indexAnneeAffichee + 1);
    }
  }

  // ─── Son du shofar (même source que le web : /sounds/shofar.mp3) ───

  /// Écoute l'annonce du shofar — le fichier est servi par le backend
  /// partagé du projet mère (bouton « 🔊 Écouter » du CalendarWorkspace).
  Future<void> jouerShofar() async {
    try {
      await _shofar.stop();
      await _shofar.play(UrlSource('${AppConfig.apiBaseUrl}/sounds/shofar.mp3'));
      state = state.copyWith(shofarEnCours: true);
    } catch (_) {
      state = state.copyWith(erreur: 'Impossible de jouer le shofar.');
    }
  }

  Future<void> arreterShofar() async {
    await _shofar.stop();
    state = state.copyWith(shofarEnCours: false);
  }

  // ─── Partage d'annonce (texte IDENTIQUE au web V3.6) ───────────────

  /// Construit le texte d'annonce d'un événement — copie EXACTE du
  /// CalendarWorkspace web (partagerAnnonce).
  static String texteAnnonce(EvenementShofarModel e) {
    const joursemaines = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    String deuxChiffres(int n) => n.toString().padLeft(2, '0');
    String dateLongue(DateTime d) =>
        '${joursemaines[d.weekday - 1]} ${d.day} ${mois[d.month - 1]} ${d.year}';
    String heure(DateTime d) => '${deuxChiffres(d.hour)}:${deuxChiffres(d.minute)}';
    // Heure de Jérusalem = UTC+2 (le web formate en tz Asia/Jérusalem).
    final jerusalem = e.entree.toUtc().add(const Duration(hours: 2));
    final locale = e.entree;

    if (e.type == 'shabbat') {
      return '📯 Shabbat Shalom !\n\n'
          'Le Shabbat entre ${dateLongue(e.entree)}, au coucher du soleil — '
          '${heure(jerusalem)} à Jérusalem (${heure(locale)} heure locale).\n\n'
          '« Souviens-toi du jour du sabbat, pour le sanctifier. » — Exode 20:8';
    }
    return '📯 ${e.titre}${e.titreHebreu != null ? ' (${e.titreHebreu})' : ''}\n\n'
        'La solennité de l\'Éternel entre ${dateLongue(e.entree)}, au coucher du soleil — '
        '${heure(jerusalem)} à Jérusalem (${heure(locale)} heure locale).'
        '${e.dateBiblique != null ? '\nDate biblique : ${e.dateBiblique}.' : ''}\n\n'
        '« ${e.description?.split('.').first}. »\n'
        '${e.reference ?? 'Lévitique 23'}\n\n'
        'Le shofar retentira dans la communauté à l\'entrée de la fête.';
  }

  /// Partage l'annonce de l'événement dans une conversation (message TEXT
  /// — même comportement que le web handleShareAnnonce).
  Future<void> partagerAnnonce(EvenementShofarModel e, String conversationId) async {
    await MessagesRepository().envoyer(conversationId, texteAnnonce(e));
  }
}

/// ⭐ Provider Riverpod du calendrier biblique.
final calendarProvider = NotifierProvider<CalendarController, CalendarState>(
  CalendarController.new,
);

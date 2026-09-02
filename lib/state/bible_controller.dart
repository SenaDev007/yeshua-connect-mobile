/// État + actions de l'espace Bible mobile (miroir du BibleWorkspace web) :
/// version courante (persistée), navigation livre/chapitre, recherche
/// plein texte, marque-pages serveur, sélection de verset pour partage.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/bible_model.dart';
import '../data/repositories/bible_repository.dart';
import '../data/repositories/messages_repository.dart';

/// Onglets de l'écran Bible (le web : Lecture · Recherche · …).
enum BibleOnglet { lecture, recherche, marquePages }

class BibleState {
  final String versionCode;
  final String livreId;
  final int chapitre;

  final ChapitreBibleModel? chapitreData;
  final bool chargement;
  final String? erreur;

  final BibleOnglet onglet;

  // Recherche
  final String requete;
  final List<ResultatRechercheBibleModel> resultats;
  final bool rechercheEnCours;

  // Marque-pages (base du projet mère — partagés avec le web)
  final List<MarquePageBibleModel> marquePages;

  /// Verset sélectionné (bottom sheet Marque-page / Partager).
  final VersetBibleModel? versetSelectionne;

  const BibleState({
    this.versionCode = 'fr-apee',
    this.livreId = 'jo',
    this.chapitre = 3,
    this.chapitreData,
    this.chargement = false,
    this.erreur,
    this.onglet = BibleOnglet.lecture,
    this.requete = '',
    this.resultats = const [],
    this.rechercheEnCours = false,
    this.marquePages = const [],
    this.versetSelectionne,
  });

  BibleState copyWith({
    String? versionCode,
    String? livreId,
    int? chapitre,
    ChapitreBibleModel? chapitreData,
    bool? chargement,
    bool clearErreur = false,
    String? erreur,
    BibleOnglet? onglet,
    String? requete,
    List<ResultatRechercheBibleModel>? resultats,
    bool? rechercheEnCours,
    List<MarquePageBibleModel>? marquePages,
    Object? versetSelectionne = _sentinelle,
  }) =>
      BibleState(
        versionCode: versionCode ?? this.versionCode,
        livreId: livreId ?? this.livreId,
        chapitre: chapitre ?? this.chapitre,
        chapitreData: chapitreData ?? this.chapitreData,
        chargement: chargement ?? this.chargement,
        erreur: clearErreur ? null : (erreur ?? this.erreur),
        onglet: onglet ?? this.onglet,
        requete: requete ?? this.requete,
        resultats: resultats ?? this.resultats,
        rechercheEnCours: rechercheEnCours ?? this.rechercheEnCours,
        marquePages: marquePages ?? this.marquePages,
        versetSelectionne: versetSelectionne == _sentinelle
            ? this.versetSelectionne
            : versetSelectionne as VersetBibleModel?,
      );

  static const _sentinelle = Object();
}

class BibleController extends Notifier<BibleState> {
  final BibleRepository _repo = BibleRepository();
  static const _kVersionKey = 'yc_bible_version';
  static const _kPositionKey = 'yc_bible_position';

  @override
  BibleState build() {
    _restaurer();
    return const BibleState();
  }

  /// Restaure la dernière version + position de lecture (persistées).
  Future<void> _restaurer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString(_kVersionKey);
      final position = prefs.getString(_kPositionKey);
      if (version == null && position == null) {
        await chargerMarquePages();
        return;
      }
      final parts = (position ?? '').split(':');
      final livreId = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'jo';
      final chapitre = parts.length > 1 ? int.tryParse(parts[1]) ?? 3 : 3;
      state = state.copyWith(
        versionCode: version ?? 'fr-apee',
        livreId: livreId,
        chapitre: chapitre,
      );
      await _chargerChapitre();
      await chargerMarquePages();
    } catch (_) {
      // Restauration best effort — la position par défaut reste valable.
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LECTURE
  // ═══════════════════════════════════════════════════════════════════

  /// Ouvre un livre/chapitre (et le mémorise).
  Future<void> ouvrir(String livreId, int chapitre) async {
    state = state.copyWith(livreId: livreId, chapitre: chapitre, clearErreur: true);
    await _persisterPosition();
    await _chargerChapitre();
  }

  /// Change de version biblique et recharge le chapitre courant.
  Future<void> changerVersion(String code) async {
    if (code == state.versionCode) return;
    state = state.copyWith(versionCode: code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVersionKey, code);
    await _chargerChapitre();
  }

  /// Chapitre précédent (traverse les livres à l'envers).
  Future<void> chapitrePrecedent() async {
    final livre = livreBibleParId(state.livreId);
    if (livre == null) return;
    if (state.chapitre > 1) {
      await ouvrir(state.livreId, state.chapitre - 1);
      return;
    }
    final i = kLivresBible.indexOf(livre);
    if (i > 0) {
      final precedent = kLivresBible[i - 1];
      await ouvrir(precedent.id, precedent.chapitres);
    }
  }

  /// Chapitre suivant (traverse les livres vers l'avant).
  Future<void> chapitreSuivant() async {
    final livre = livreBibleParId(state.livreId);
    if (livre == null) return;
    if (state.chapitre < livre.chapitres) {
      await ouvrir(state.livreId, state.chapitre + 1);
      return;
    }
    final i = kLivresBible.indexOf(livre);
    if (i < kLivresBible.length - 1) {
      final suivant = kLivresBible[i + 1];
      await ouvrir(suivant.id, 1);
    }
  }

  Future<void> rafraichir() => _chargerChapitre();

  Future<void> _chargerChapitre() async {
    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      final data = await _repo.chapitre(state.versionCode, state.livreId, state.chapitre);
      state = state.copyWith(chapitreData: data, chargement: false);
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: e.toString());
    }
  }

  Future<void> _persisterPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPositionKey, '${state.livreId}:${state.chapitre}');
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  //  RECHERCHE
  // ═══════════════════════════════════════════════════════════════════

  Future<void> rechercher(String q) async {
    final requete = q.trim();
    state = state.copyWith(requete: requete);
    if (requete.isEmpty) {
      state = state.copyWith(resultats: const []);
      return;
    }
    state = state.copyWith(rechercheEnCours: true, clearErreur: true);
    try {
      final resultats = await _repo.recherche(state.versionCode, requete);
      state = state.copyWith(resultats: resultats, rechercheEnCours: false);
    } catch (e) {
      state = state.copyWith(rechercheEnCours: false, erreur: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MARQUE-PAGES (base partagée avec le web)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> chargerMarquePages() async {
    try {
      final marques = await _repo.marquePages();
      state = state.copyWith(marquePages: marques);
    } catch (_) {
      // Non-bloquant : l'onglet marque-pages affichera l'erreur au rechargement.
    }
  }

  /// Marque le verset sélectionné (upsert serveur) puis referme.
  Future<void> marquerVersetSelectionne({String? note}) async {
    final v = state.versetSelectionne;
    if (v == null) return;
    final livre = livreBibleParId(state.livreId);
    await _repo.ajouterMarquePage(
      version: state.versionCode,
      livreId: state.livreId,
      livreNom: livre?.nom ?? state.livreId,
      chapitre: state.chapitre,
      verset: v.numero,
      texte: v.texte,
      note: note,
    );
    state = state.copyWith(versetSelectionne: null);
    await chargerMarquePages();
  }

  Future<void> supprimerMarquePage(String id) async {
    await _repo.supprimerMarquePage(id);
    await chargerMarquePages();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SÉLECTION & PARTAGE DE VERSET (message VERSE — même format que le web)
  // ═══════════════════════════════════════════════════════════════════

  void selectionnerVerset(VersetBibleModel? verset) {
    state = state.copyWith(versetSelectionne: verset);
  }

  /// Partage le verset sélectionné dans une conversation — POST message
  /// { content: référence, type: "VERSE", verseRef, verseText } (V2.6 web).
  Future<void> partagerVerset(String conversationId) async {
    final v = state.versetSelectionne;
    if (v == null) return;
    final livre = livreBibleParId(state.livreId);
    final reference = '${livre?.nom ?? state.livreId} ${state.chapitre}:${v.numero}';
    await MessagesRepository().envoyerVerset(conversationId, reference, v.texte);
    state = state.copyWith(versetSelectionne: null);
  }

  // ─── UI ─────────────────────────────────────────────────────────────

  void changerOnglet(BibleOnglet onglet) {
    state = state.copyWith(onglet: onglet);
    if (onglet == BibleOnglet.marquePages) chargerMarquePages();
  }
}

/// ⭐ Provider Riverpod de l'espace Bible.
final bibleProvider = NotifierProvider<BibleController, BibleState>(
  BibleController.new,
);

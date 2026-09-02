/// Recherche globale avec anti-tâche (debounce 400 ms).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/search_models.dart';
import '../data/repositories/search_repository.dart';
class SearchState {
  final String query;
  final SearchResults resultats;
  final bool enCours;

  const SearchState({this.query = '', this.resultats = const SearchResults(), this.enCours = false});

  SearchState copyWith({String? query, SearchResults? resultats, bool? enCours}) => SearchState(
        query: query ?? this.query,
        resultats: resultats ?? this.resultats,
        enCours: enCours ?? this.enCours,
      );
}

class SearchController extends StateNotifier<SearchState> {
  final SearchRepository _repo = SearchRepository();
  Timer? _debounce;

  SearchController() : super(const SearchState());

  void onQueryChanged(String q) {
    state = state.copyWith(query: q);
    _debounce?.cancel();
    if (q.trim().length < 2) {
      state = state.copyWith(resultats: const SearchResults(), enCours: false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => lancer(q));
  }

  Future<void> lancer(String q) async {
    state = state.copyWith(enCours: true);
    try {
      final resultats = await _repo.rechercher(q.trim());
      // Résultat obsolète ? (l'utilisateur a continué à taper)
      if (state.query.trim() == q.trim()) {
        state = state.copyWith(resultats: resultats, enCours: false);
      }
    } catch (_) {
      state = state.copyWith(enCours: false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider<SearchController, SearchState>(
  (ref) => SearchController(),
);

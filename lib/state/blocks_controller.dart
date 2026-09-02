/// ⭐ V1.5 — Contrôleur des blocages (bloquer / débloquer / liste).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/blocks_models.dart';
import '../data/repositories/blocks_repository.dart';

class BlocksState {
  final bool chargement;
  final List<MembreBloqueModel> bloques;

  /// Ids des membres qui m'ont bloqué — sert à griser discrètement les
  /// actions « message privé » SANS révéler qui (comportement web V3.5).
  final List<String> bloqueursIds;
  final String? erreur;

  const BlocksState({
    this.chargement = false,
    this.bloques = const [],
    this.bloqueursIds = const [],
    this.erreur,
  });

  bool estBloque(String userId) =>
      bloques.any((m) => m.userId == userId);

  bool mABloque(String userId) => bloqueursIds.contains(userId);

  BlocksState copyWith({
    bool? chargement,
    List<MembreBloqueModel>? bloques,
    List<String>? bloqueursIds,
    String? erreur,
    bool clearErreur = false,
  }) =>
      BlocksState(
        chargement: chargement ?? this.chargement,
        bloques: bloques ?? this.bloques,
        bloqueursIds: bloqueursIds ?? this.bloqueursIds,
        erreur: clearErreur ? null : (erreur ?? this.erreur),
      );
}

class BlocksController extends StateNotifier<BlocksState> {
  final BlocksRepository _repo = BlocksRepository();

  BlocksController() : super(const BlocksState()) {
    charger();
  }

  Future<void> charger() async {
    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      final r = await _repo.lister();
      state = state.copyWith(
        chargement: false,
        bloques: r.bloques,
        bloqueursIds: r.bloqueursIds,
      );
    } catch (e) {
      state = state.copyWith(chargement: false, erreur: e.toString());
    }
  }

  /// Bloque un membre + rafraîchit la liste locale.
  Future<void> bloquer(String userId) async {
    await _repo.bloquer(userId);
    await charger();
  }

  /// Débloque un membre + rafraîchit la liste locale.
  Future<void> debloquer(String userId) async {
    await _repo.debloquer(userId);
    await charger();
  }
}

/// Provider global des blocages (chargé à l'ouverture, rafraîchi sur action).
final blocksProvider =
    StateNotifierProvider<BlocksController, BlocksState>(
  (ref) => BlocksController(),
);

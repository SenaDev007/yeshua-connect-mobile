/// ⭐ V2.0 — BASE DE DONNÉES LOCALE SQLITE.
///
/// « Une base de données locale intégrée » (exigence du pasteur) : tout
/// le contenu public du site y est mis en miroir à chaque synchronisation
/// (`GET /api/app/sync`), et les messages rédigés hors ligne y attendent
/// le retour du réseau (table `outbox` — envoi différé « façon WhatsApp »).
///
/// Tables :
///   · contenu(cle, json, maj)   — une ligne par section (serviteurs,
///     héros, témoignages, enseignements, vidéos, vies transformées,
///     annonces, lives, disperses) : le JSON brut de la synchronisation,
///     relu et parsé au démarrage SANS réseau ;
///   · outbox(id, conversation_id, contenu, reponse_a, cree_le, tentatives)
///     — file FIFO des messages texte en attente d'envoi ;
///   · meta(cle, valeur)         — hash de la dernière synchronisation,
///     date du dernier essai…
///
/// Les conversations/messages de Yeshua Connect continuent d'utiliser
/// le cache JSON existant (V1.8) — SQLite est dédié au CONTENU PUBLIC
/// et à l'outbox.
library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbLocal {
  DbLocal._();
  static final DbLocal instance = DbLocal._();

  Database? _base;

  /// Ouvre (et crée si nécessaire) la base — idempotent.
  Future<Database> get base async {
    if (_base != null) return _base!;
    final dir = await getApplicationDocumentsDirectory();
    _base = await openDatabase(
      p.join(dir.path, 'christ-libere.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contenu (
            cle  TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            maj  TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE outbox (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id TEXT NOT NULL,
            contenu          TEXT NOT NULL,
            reponse_a        TEXT,
            cree_le          TEXT NOT NULL,
            tentatives       INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_outbox_conv ON outbox(conversation_id)',
        );
        await db.execute('''
          CREATE TABLE meta (
            cle    TEXT PRIMARY KEY,
            valeur TEXT NOT NULL
          )
        ''');
      },
    );
    return _base!;
  }

  // ═════════════════════════════════════════════════════════════════
  //  CONTENU PUBLIC (miroir de /api/app/sync)
  // ═════════════════════════════════════════════════════════════════

  /// Écrit (remplace) une section de contenu — JSON encodé en texte.
  Future<void> ecrireContenu(String cle, Object valeur) async {
    final db = await base;
    await db.insert(
      'contenu',
      {
        'cle': cle,
        'json': jsonEncode(valeur),
        'maj': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lit une section de contenu (null si jamais synchronisée).
  Future<dynamic> lireContenu(String cle) async {
    final db = await base;
    final lignes = await db.query(
      'contenu',
      columns: ['json'],
      where: 'cle = ?',
      whereArgs: [cle],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    try {
      return jsonDecode(lignes.first['json'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Date de dernière écriture d'une section (null si absente).
  Future<DateTime?> dateMajContenu(String cle) async {
    final db = await base;
    final lignes = await db.query(
      'contenu',
      columns: ['maj'],
      where: 'cle = ?',
      whereArgs: [cle],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    return DateTime.tryParse(lignes.first['maj'] as String? ?? '');
  }

  // ═════════════════════════════════════════════════════════════════
  //  OUTBOX — messages rédigés hors ligne
  // ═════════════════════════════════════════════════════════════════

  /// Ajoute un message à la file d'envoi.
  Future<int> ajouterOutbox(
    String conversationId,
    String contenu, {
    String? reponseA,
  }) async {
    final db = await base;
    return db.insert('outbox', {
      'conversation_id': conversationId,
      'contenu': contenu,
      'reponse_a': reponseA,
      'cree_le': DateTime.now().toIso8601String(),
      'tentatives': 0,
    });
  }

  /// File complète (FIFO : id croissant).
  Future<List<Map<String, Object?>>> lireOutbox() async {
    final db = await base;
    return db.query('outbox', orderBy: 'id ASC');
  }

  /// Messages en attente POUR une conversation (FIFO).
  Future<List<Map<String, Object?>>> lireOutboxConversation(
    String conversationId,
  ) async {
    final db = await base;
    return db.query(
      'outbox',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'id ASC',
    );
  }

  /// Nombre total de messages en attente (badge éventuel).
  Future<int> compterOutbox() async {
    final db = await base;
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM outbox');
    return (r.first['n'] as int? ?? 0);
  }

  /// Supprime un message envoyé avec succès.
  Future<void> supprimerOutbox(int id) async {
    final db = await base;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  /// Incrémente le compteur de tentatives (diagnostic).
  Future<void> noterTentative(int id) async {
    final db = await base;
    await db.rawUpdate(
      'UPDATE outbox SET tentatives = tentatives + 1 WHERE id = ?',
      [id],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  META (hash de synchronisation…)
  // ═════════════════════════════════════════════════════════════════

  Future<void> ecrireMeta(String cle, String valeur) async {
    final db = await base;
    await db.insert(
      'meta',
      {'cle': cle, 'valeur': valeur},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> lireMeta(String cle) async {
    final db = await base;
    final lignes = await db.query(
      'meta',
      columns: ['valeur'],
      where: 'cle = ?',
      whereArgs: [cle],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    return lignes.first['valeur'] as String?;
  }
}

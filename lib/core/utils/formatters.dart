/// Formatage FR : dates, heures, durées d'appel, aperçus de messages.
library;

import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// « 14:32 » — heure d'un message.
  static String heure(DateTime? d) =>
      d == null ? '' : DateFormat('HH:mm', 'fr_FR').format(d);

  /// « aujourd'hui », « hier », « mar. 12 août » — entête de section.
  static String jour(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return "aujourd'hui";
    if (diff == 1) return 'hier';
    return DateFormat('EEE d MMM', 'fr_FR').format(d);
  }

  /// « 14:32 » / « hier 09:10 » / « 12/08 14:32 » — dernier message d'une tuile.
  static String horodatage(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return DateFormat('HH:mm', 'fr_FR').format(d);
    if (diff == 1) return 'hier ${DateFormat('HH:mm', 'fr_FR').format(d)}';
    return DateFormat('dd/MM HH:mm', 'fr_FR').format(d);
  }

  /// « Pam · il y a 5 min » pour les résultats de recherche.
  static String tempsRelatif(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
  }

  /// 192 s → « 3 min 12 s » ; 45 s → « 45 s » — même logique que le web.
  static String dureeAppel(int secondes) {
    if (secondes < 60) return '$secondes s';
    final m = secondes ~/ 60;
    final s = secondes % 60;
    if (m < 60) return s > 0 ? '$m min $s s' : '$m min';
    final h = m ~/ 60;
    return '$h h ${m % 60} min';
  }

  /// Chrono en direct d'un appel : « 04:37 ».
  static String chrono(int secondes) {
    final m = (secondes ~/ 60).toString().padLeft(2, '0');
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Label lisible d'un type de conversation.
  static String labelType(String type) {
    switch (type) {
      case 'DIRECT':
        return 'Privé';
      case 'GROUP':
        return 'Groupe';
      case 'PASTORS':
        return 'Pasteurs';
      case 'VOICE':
        return 'Vocal';
      case 'CHANNEL':
      default:
        return 'Canal';
    }
  }

  /// Label d'un rôle global (badge membre).
  static String labelRole(String? role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return 'Admin principal';
      case 'ADMIN':
        return 'Admin';
      case 'MODERATOR':
        return 'Modérateur';
      case 'ANIMATOR':
        return 'Animateur';
      case 'PASTOR':
        return 'Pasteur';
      case 'MEMBER':
      default:
        return 'Membre';
    }
  }

  /// Aperçu compact d'un message dans la liste (remplace les retours ligne).
  static String apercu(String? content, {int max = 60}) {
    if (content == null || content.isEmpty) return '';
    final flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= max) return flat;
    return '${flat.substring(0, max)}…';
  }
}

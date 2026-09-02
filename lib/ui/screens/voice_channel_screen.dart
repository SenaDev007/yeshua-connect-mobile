/// ⭐ ÉCRAN DÉDIÉ — Canal vocal persistant (parité web : VoiceChannelPanel
/// + joinVoiceChannel V2.7/V2.9/V3.21) :
///
///   • Rejoindre / quitter la room `yeshua-voice-<convId>` (persistante) ;
///   • participants connectés (micro, parole — orateur mis en avant) ;
///   • micro local, caméra SI l'admin a activé le mode vidéo ;
///   • ADMIN : bascule Audio ↔ Vidéo du canal (propagée à tous à chaud) ;
///   • badge « Réseau : LiveKit/Agora/Daily » + bandeau de bascule
///     automatique (chaîne de repli du serveur — directive pasteur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/call_media_controller.dart'
    show MediaParticipant, MediaProviderNomX;
import '../../state/conversations_controller.dart';
import '../../state/voice_channel_controller.dart';
import '../widgets/avatar_widget.dart';

class VoiceChannelScreen extends ConsumerWidget {
  const VoiceChannelScreen({super.key, required this.conversationId});

  final String conversationId;

  static const _rolesAdmin = {'SUPER_ADMIN', 'ADMIN', 'MODERATOR', 'ANIMATOR'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(voiceChannelProvider);
    final conv = ref.watch(conversationsProvider).conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;
    final nom = etat.nomCanal ?? conv?.name ?? 'Canal vocal';
    final monRole = ref.watch(authProvider).user?.role;
    final estAdmin = _rolesAdmin.contains(monRole ?? '');

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Canal vocal', style: TextStyle(fontSize: 17)),
            Text(
              nom,
              style: const TextStyle(
                color: AppColors.texteSecondaire,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (etat.connecte)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                backgroundColor: AppColors.pourpreClair,
                visualDensity: VisualDensity.compact,
                label: Text(
                  'Réseau : ${etat.fournisseur.libelle}',
                  style: const TextStyle(color: AppColors.orPastel, fontSize: 11.5),
                ),
                avatar: Icon(
                  Icons.network_check,
                  size: 14,
                  color: etat.fournisseur.libelle == 'LiveKit'
                      ? AppColors.enLigne
                      : AppColors.or,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau de bascule automatique (chaîne de repli serveur).
          if (etat.basculeEnCours)
            Container(
              width: double.infinity,
              color: AppColors.or.withOpacity(0.16),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: AppColors.or, strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bascule automatique vers le réseau de secours…',
                      style: TextStyle(color: AppColors.orPastel, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: etat.connecte
                ? _vueConnecte(context, ref, etat, estAdmin)
                : _vueHorsLigne(context, ref, etat),
          ),
        ],
      ),
    );
  }

  // ─── Vue non connecté : rejoindre ───────────────────────────────────

  Widget _vueHorsLigne(BuildContext context, WidgetRef ref, VoiceChannelState etat) {
    if (etat.chargement) {
      return const Center(child: CircularProgressIndicator(color: AppColors.or));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.pourpre,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.or.withOpacity(0.4)),
              ),
              child: const Icon(Icons.graphic_eq, color: AppColors.or, size: 42),
            ),
            const SizedBox(height: 20),
            const Text(
              'Canal vocal de la communauté',
              style: TextStyle(
                color: AppColors.texte,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rejoignez la room persistante : vous pouvez partir et revenir,\n'
              'les autres restent connectés. Réseau arbitré par le serveur :\n'
              'LiveKit → Agora → Daily (bascule automatique).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.texteSecondaire, height: 1.5, fontSize: 13),
            ),
            if (etat.erreur != null) ...[
              const SizedBox(height: 14),
              Text(
                etat.erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              onPressed: () => ref
                  .read(voiceChannelProvider.notifier)
                  .rejoindre(conversationId: conversationId, nomCanal: etat.nomCanal ?? 'Canal vocal'),
              icon: const Icon(Icons.headphones),
              label: const Text('Rejoindre le canal vocal', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Vue connectée : participants + contrôles ───────────────────────

  Widget _vueConnecte(BuildContext context, WidgetRef ref, VoiceChannelState etat, bool estAdmin) {
    final moi = ref.watch(authProvider).user;
    final controller = ref.read(voiceChannelProvider.notifier);
    final tuiles = <Widget>[
      // Moi en tête.
      MediaMoi(
        nom: moi?.name ?? 'Moi',
        microCoupe: etat.microCoupe,
        cameraActive: etat.cameraActive,
      ).carte(context),
      for (final p in etat.participants) MediaDistant(participant: p).carte(context),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            itemCount: tuiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => tuiles[i],
          ),
        ),
        // ADMIN — bascule du mode du canal (audio ↔ vidéo, propagée à chaud).
        if (estAdmin)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pourpre,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              value: etat.videoMode,
              activeColor: AppColors.or,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Mode vidéo du canal',
                style: TextStyle(color: AppColors.texte, fontSize: 14),
              ),
              subtitle: const Text(
                'Administrateur : tout le monde suit à chaud',
                style: TextStyle(color: AppColors.texteSecondaire, fontSize: 11.5),
              ),
              onChanged: (v) => controller.basculerModeCanal(video: v),
            ),
          ),
        if (etat.erreur != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              etat.erreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        // Contrôles : micro · caméra (si mode vidéo) · quitter.
        Container(
          color: AppColors.pourpre,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _boutonControle(
                actif: !etat.microCoupe,
                icone: etat.microCoupe ? Icons.mic_off : Icons.mic,
                libelle: etat.microCoupe ? 'Réactivé' : 'Micro',
                onTap: controller.basculerMicro,
              ),
              if (etat.videoMode)
                _boutonControle(
                  actif: etat.cameraActive,
                  icone: Icons.videocam,
                  libelle: etat.cameraActive ? 'Caméra' : 'Caméra off',
                  onTap: controller.basculerCamera,
                ),
              _boutonControle(
                actif: false,
                danger: true,
                icone: Icons.logout,
                libelle: 'Quitter',
                onTap: controller.quitter,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _boutonControle({
    required bool actif,
    required IconData icone,
    required String libelle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: danger
              ? AppColors.danger.withOpacity(0.18)
              : actif
                  ? AppColors.or.withOpacity(0.2)
                  : AppColors.nuitClair,
          child: IconButton(
            icon: Icon(
              icone,
              color: danger ? AppColors.danger : (actif ? AppColors.or : AppColors.texteSecondaire),
              size: 24,
            ),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          libelle,
          style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 11),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  TUILES PARTICIPANTS
// ═══════════════════════════════════════════════════════════════════════

/// Ligne « moi ».
class MediaMoi {
  final String nom;
  final bool microCoupe;
  final bool cameraActive;

  const MediaMoi({required this.nom, required this.microCoupe, required this.cameraActive});

  Widget carte(BuildContext context) => _tuile(
        nom: '$nom (vous)',
        microActif: !microCoupe,
        cameraActive: cameraActive,
        parle: !microCoupe,
      );
}

/// Ligne participant distant (normalisée — LiveKit/Agora).
class MediaDistant {
  final MediaParticipant participant;

  const MediaDistant({required this.participant});

  Widget carte(BuildContext context) => _tuile(
        nom: participant.name ?? participant.identity,
        microActif: participant.microActif,
        cameraActive: participant.cameraActive,
        parle: participant.parle,
      );
}

Widget _tuile({
  required String nom,
  required bool microActif,
  required bool cameraActive,
  required bool parle,
}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: parle ? AppColors.or.withOpacity(0.14) : AppColors.pourpreClair.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: parle ? Border.all(color: AppColors.or.withOpacity(0.45)) : null,
      ),
      child: Row(
        children: [
          AvatarWidget(photoUrl: null, name: nom, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nom,
              style: TextStyle(
                color: parle ? AppColors.or : AppColors.texte,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
          if (cameraActive)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.videocam, color: AppColors.orPastel, size: 18),
            ),
          Icon(
            microActif ? Icons.mic : Icons.mic_off,
            color: microActif ? AppColors.texteSecondaire : AppColors.danger,
            size: 18,
          ),
        ],
      ),
    );

/// ⭐ V2.0 — LECTEUR VIDÉO INTÉGRÉ (MP4 / HLS de NOS serveurs).
///
/// Ne sert QUE les fichiers que le Mouvement héberge lui-même (copie R2
/// des MP4 TikTok, replays, rendus post-production) : lecture dans l'app,
/// sans sortie vers YouTube/TikTok. Les vidéos externes passent par
/// leurs applications officielles (cf. CarteVideo.ouvrir).
///
/// La lecture exige une connexion Internet (seule fonction du ministère
/// dans ce cas — exigence explicite du pasteur).
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';

class LecteurVideoScreen extends StatefulWidget {
  final String url;
  final String titre;

  const LecteurVideoScreen({super.key, required this.url, required this.titre});

  @override
  State<LecteurVideoScreen> createState() => _LecteurVideoScreenState();
}

class _LecteurVideoScreenState extends State<LecteurVideoScreen> {
  VideoPlayerController? _controleur;
  bool _erreur = false;
  bool _enPleinEcran = false;

  @override
  void initState() {
    super.initState();
    if (!Connectivite.instance.enLigne) {
      _erreur = true;
      return;
    }
    _controleur = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controleur?.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _erreur = true);
      });
  }

  @override
  void dispose() {
    _controleur?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Barre supérieure (retour + titre) — masquée en plein écran.
          if (!_enPleinEcran)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.or),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _erreur
                ? _EtatErreur(url: widget.url)
                : c == null || !c.value.isInitialized
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.or),
                      )
                    : GestureDetector(
                        // Tap : lecture/pause ; en mode « plein écran »
                        // (barres masquées) un second tap les ramène.
                        onTap: () {
                          setState(() {
                            if (_enPleinEcran) {
                              _enPleinEcran = false;
                            } else {
                              c.value.isPlaying ? c.pause() : c.play();
                            }
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(child: AspectRatio(
                              aspectRatio: c.value.aspectRatio == 0
                                  ? 16 / 9
                                  : c.value.aspectRatio,
                              child: VideoPlayer(c),
                            )),
                            if (!c.value.isPlaying)
                              const Icon(Icons.play_arrow,
                                  size: 64, color: AppColors.or),
                          ],
                        ),
                      ),
          ),
          // Barre de contrôle (progression + durées) — masquée en plein écran.
          if (!_enPleinEcran && _controleur != null && _controleur!.value.isInitialized)
            _BarreControle(
              controleur: _controleur!,
              onPleinEcran: () => setState(() => _enPleinEcran = true),
            )
          else if (_enPleinEcran)
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(Icons.fullscreen_exit, color: Colors.white24, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _EtatErreur extends StatelessWidget {
  final String url;

  const _EtatErreur({required this.url});

  @override
  Widget build(BuildContext context) {
    final horsLigne = !Connectivite.instance.enLigne;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              horsLigne ? Icons.wifi_off : Icons.error_outline,
              size: 46,
              color: AppColors.orPastel,
            ),
            const SizedBox(height: 14),
            Text(
              horsLigne
                  ? 'La lecture des vidéos nécessite une connexion Internet.'
                  : 'Cette vidéo n\'a pas pu être chargée. Réessayez avec une connexion stable.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texteSecondaire,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreControle extends StatelessWidget {
  final VideoPlayerController controleur;
  final VoidCallback onPleinEcran;

  const _BarreControle({required this.controleur, required this.onPleinEcran});

  static String _duree(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controleur,
              builder: (context, value, _) => IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: AppColors.or,
                ),
                onPressed: () =>
                    value.isPlaying ? controleur.pause() : controleur.play(),
              ),
            ),
            Expanded(
              child: VideoProgressIndicator(
                controleur,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.or,
                  backgroundColor: Colors.white24,
                  bufferedColor: Colors.white38,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controleur,
              builder: (context, value, _) => Text(
                '${_duree(value.position)} / ${_duree(value.duration)}',
                style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 11.5),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: AppColors.or),
              onPressed: onPleinEcran,
            ),
          ],
        ),
      ),
    );
  }
}

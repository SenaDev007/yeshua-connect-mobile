/// Écran d'attente pendant la restauration de session JWT.
///
/// ⭐ V1.7 — IDENTITÉ OFFICIELLE, calquée sur l'intro du site web
/// (`landing-intro.tsx` — « Le shofar retentit… ») :
///   • logo officiel Christ Libère au centre, double halo doré, pulsation ;
///   • « Christ Libère » / « Le shofar retentit… » / « Ouverture de la
///     visitation » ;
///   • barre de chargement 5 s en POURCENTAGE (dégradé or) ;
///   • SON DU SHOFAR (assets/sounds/shofar.mp3 — même fichier que le web,
///     30 s) qui continue après l'ouverture, comme sur le site ;
///   • bouton « Passer » (le shofar poursuit jusqu'à 30 s, fidèle au web) ;
///   • ⭐ V2.8 — BOUTON MUET : le shofar peut déranger (il retentit à
///     CHAQUE lancement) — un bouton haut-parleur le coupe immédiatement
///     ET retient le choix pour les prochains lancements (mode muet
///     global, partagé avec la sonnerie d'appel sortant).
///
/// Dès que l'état d'auth tranche (ET que le minimum de 5 s est écoulé),
/// on route vers login ou app.
library;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/sons_controller.dart';
import '../widgets/bouton_muet_sonnerie.dart';

/// Copie un asset embarqué vers un fichier temporaire — lecture 100 %
/// fiable par audioplayers (DeviceFileSource), indépendante des
/// conventions de préfixe « assets/ » propres à chaque version du plugin.
Future<String> cheminAssetSon(String cleAsset) async {
  final dir = await getTemporaryDirectory();
  final nom = cleAsset.split('/').last;
  final f = File('${dir.path}/yc_$nom');
  if (!await f.exists()) {
    final octets = await rootBundle.load(cleAsset);
    await f.writeAsBytes(
        octets.buffer.asUint8List(octets.offsetInBytes, octets.lengthInBytes));
  }
  return f.path;
}

/// Lecteur du shofar d'intro — VIT HORS de l'écran pour que le son
/// POURSUIVE après l'ouverture (comportement du web : « le shofar, lui,
/// continue jusqu'à 30 s »). Auto-stop à 30 s.
class ShofarIntro {
  static AudioPlayer? _joueur;
  static Timer? _fin;

  static Future<void> jouer() async {
    if (_joueur != null) return; // une seule fois par lancement d'app
    // ⭐ V2.8 — MODE MUET GLOBAL : si l'utilisateur a coupé les sonneries,
    // le shofar ne retentit pas du tout (choix persisté, bouton du splash
    // ou du menu tiroir).
    if (await Sons.estMuet()) return;
    final j = AudioPlayer();
    _joueur = j;
    j.onPlayerComplete.listen((_) => arreter());
    try {
      final chemin = await cheminAssetSon('assets/sounds/shofar.mp3');
      await j.play(DeviceFileSource(chemin), volume: 0.85);
      _fin = Timer(const Duration(seconds: 30), arreter);
    } catch (_) {
      arreter();
    }
  }

  static Future<void> arreter() async {
    _fin?.cancel();
    _fin = null;
    final j = _joueur;
    _joueur = null;
    if (j != null) {
      try {
        await j.stop();
      } catch (_) {}
      j.dispose();
    }
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _dureeMin = Duration(seconds: 5); // barre 5 s comme le web

  late final AnimationController _pulse;
  Timer? _tic;
  DateTime _debut = DateTime.now();
  int _pourcentage = 0;
  bool _minAtteint = false;
  bool _parti = false;
  AuthStatus? _statutTranche;

  @override
  void initState() {
    super.initState();
    _debut = DateTime.now();

    // Pulsation du logo (2,6 s — même rythme que l'intro web).
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
      lowerBound: 0.97,
      upperBound: 1.04,
    )..repeat(reverse: true);

    // Le shofar (même fichier que le web — POURSUIT après l'ouverture,
    // jusqu'à 30 s, via le lecteur statique _ShofarIntro).
    unawaited(ShofarIntro.jouer());

    // Barre de progression (10 Hz) + ouverture dès que le minimum tombe.
    _tic = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final ecoule = DateTime.now().difference(_debut);
      final p = (ecoule.inMilliseconds / _dureeMin.inMilliseconds * 100)
          .clamp(0, 100)
          .toInt();
      setState(() => _pourcentage = p);
      if (ecoule >= _dureeMin && !_minAtteint) {
        _minAtteint = true;
        _tentativeOuverture();
      }
    });
  }

  @override
  void dispose() {
    _tic?.cancel();
    _pulse.dispose();
    super.dispose();
    // NB : le shofar N'EST PAS stoppé ici — il vit dans _ShofarIntro et
    // s'arrête de lui-même (30 s / fin de piste), exactement comme le web.
  }

  void _tentativeOuverture() {
    if (_parti) return;
    final statut = _statutTranche;
    if (statut == null) return; // on attend encore l'auth
    if (!_minAtteint) return; // intro de 5 s honorée
    _parti = true;
    // Le shofar continue ≤ 30 s (lecteur statique) — comme sur le web.
    // ⭐ V2.0 — l'accueil du ministère est PUBLIC : tout le monde entre,
    // connecté ou non (les membres retrouvent Yeshua Connect en 1 geste).
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    // Écoute l'état d'auth : dès qu'il tranche, route (après le mini 5 s).
    ref.listen<AuthState>(authProvider, (previous, next) {
      _statutTranche = next.status;
      if (next.status == AuthStatus.authenticated ||
          next.status == AuthStatus.unauthenticated) {
        _tentativeOuverture();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.nuit,
      body: Stack(
        children: [
          // ── Halo radial doré (comme l'intro web) ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.24), // 50 % / 38 % comme le web
                    radius: 1.1,
                    colors: [
                      Color(0x38C9A227), // or 22 %
                      Color(0x14C9A227), // or 8 %
                      Color(0x001E0F2B),
                    ],
                    stops: [0.0, 0.34, 0.62],
                  ),
                ),
              ),
            ),
          ),
          // ── Liserés or haut/bas ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: AppColors.or.withValues(alpha: 0.6),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: AppColors.or.withValues(alpha: 0.6),
            ),
          ),
          // ── Contenu centré ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ⭐ LE LOGO OFFICIEL — double halo + pulsation
                    ScaleTransition(
                      scale: _pulse,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.or.withValues(alpha: 0.28),
                                  AppColors.or.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.7],
                              ),
                            ),
                          ),
                          Image.asset(
                            'assets/images/logo-christ-libere.png',
                            width: 148,
                            excludeFromSemantics: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Christ Libère',
                      style: TextStyle(
                        color: Color(0xFFFAF6EF),
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Le shofar retentit…',
                      style: TextStyle(
                        color: AppColors.or,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'OUVERTURE DE LA VISITATION',
                      style: TextStyle(
                        color: Color(0x80FAF6EF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // ── Barre de chargement 5 s, en pourcentage ──
                    SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 6,
                              child: LinearProgressIndicator(
                                value: _pourcentage / 100,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFFAF6EF)
                                    .withValues(alpha: 0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.or),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$_pourcentage %',
                                style: const TextStyle(
                                  color: Color(0x99FAF6EF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const Text(
                                'CHARGEMENT',
                                style: TextStyle(
                                  color: AppColors.orPastel,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // ── Boutons « Passer » + ⭐ V2.8 bouton MUET ──
                    // Le shofar retentit à chaque lancement : celui qui
                    // serait dérangé le coupe ici, pour cet écran ET pour
                    // les prochains lancements (préférence persistée).
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            _minAtteint = true;
                            _statutTranche ??= AuthStatus.unauthenticated;
                            _tentativeOuverture();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orPastel,
                            side: BorderSide(
                                color: AppColors.or.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 9),
                          ),
                          child: const Text(
                            'Passer',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        BoutonMuetSonnerie(
                          onCoupe: () => unawaited(ShofarIntro.arreter()),
                          onReactive: () => unawaited(ShofarIntro.jouer()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⭐ V2.18 — PARTAGE DE TÉMOIGNAGE « VIE TRANSFORMÉE »
/// (miroir de la modale « Partager votre témoignage » de la landing web,
/// V3.100/V4.15/V4.25 — même API, mêmes règles de validation).
///
/// Le croyant raconte ce que Dieu a fait dans sa vie en DEUX étapes :
///   Étape 1 — VOUS PERSONNELLEMENT : nom, email, téléphone, pays, ville
///   (le moyen d'être recontacté — JAMAIS publié) ;
///   Étape 2 — VOTRE TÉMOIGNAGE : titre, catégorie, profession, église,
///   récit complet (10 000 caractères), consentement à la relecture
///   pastorale — ET une NOTE VOCALE de DURÉE ILLIMITÉE (V4.25).
///
/// ⭐ V2.18/V4.25 — NOTE VOCALE : l'enregistrement (package record,
/// m4a/AAC) n'a AUCUNE limite de minutes. L'audio monte DIRECTEMENT vers
/// Cloudflare R2 via une URL pré-signée (il ne transite jamais par le
/// serveur Next.js, donc aucune limite de taille non plus) :
///   1. POST /api/temoignages-croyants/audio-presign → { uploadUrl, … }
///   2. PUT binaire vers R2 (ApiClient.putOctetsVersUrl)
///   3. POST /api/temoignages-croyants avec l'URL publique + durée.
///
/// Le témoignage arrive dans le back-office (/admin/vie-transformee) en
/// statut « en_attente » : un SUPER ADMIN le relit puis le valide
/// (publication sur la landing + /vie-transformee) — RIEN n'est publié
/// sans validation.
///
/// AUCUNE CONNEXION REQUISE : comme sur la landing, l'API publique
/// POST /api/temoignages-croyants est ouverte (honeypot anti-robots).
/// L'envoi exige simplement Internet — le formulaire reste remplissable
/// hors ligne avec un message explicite (même règle que l'intercession).
library;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';

/// Catégories proposées — MÊMES clés que l'API web (contrôle serveur).
const Map<String, String> _kCategories = {
  'vie_transformee': 'Vie transformée',
  'guerison': 'Guérison',
  'delivrance': 'Délivrance',
  'restauration': 'Foyer restauré',
  'providence': 'Providence',
  'appel': 'Appel & consécration',
  'action_graces': 'Action de grâces',
};

/// ⭐ V4.25 — Limite portée à 10 000 caractères (demande du pasteur).
const int _kContenuMax = 10000;
const int _kContenuMin = 30;

class PartageTemoignageScreen extends StatefulWidget {
  const PartageTemoignageScreen({super.key});

  @override
  State<PartageTemoignageScreen> createState() =>
      _PartageTemoignageScreenState();
}

class _PartageTemoignageScreenState extends State<PartageTemoignageScreen> {
  final _formulaire = GlobalKey<FormState>();

  // ── Étape 1 — informations personnelles ──
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _pays = TextEditingController();
  final _ville = TextEditingController();

  // ── Étape 2 — le témoignage ──
  final _titre = TextEditingController();
  final _profession = TextEditingController();
  final _eglise = TextEditingController();
  final _contenu = TextEditingController();

  String _categorie = 'vie_transformee';
  bool _consentement = false;

  // ── ⭐ V2.18 — Note vocale (durée ILLIMITÉE) ──
  final AudioRecorder _enregistreur = AudioRecorder();
  final AudioPlayer _lecteurApercu = AudioPlayer();
  bool _enregistrementEnCours = false;
  bool _lectureApercu = false;
  int _secondesEnregistrees = 0;
  String? _cheminAudio;
  DateTime? _debutEnregistrement;
  Timer? _minuteurEnregistrement;

  /// 1 = vous · 2 = témoignage · 3 = reçu de confirmation.
  int _etape = 1;
  bool _envoi = false;
  bool _envoiAudio = false;

  @override
  void dispose() {
    _minuteurEnregistrement?.cancel();
    _enregistreur.dispose();
    _lecteurApercu.dispose();
    _supprimerFichierAudio();
    _nom.dispose();
    _email.dispose();
    _telephone.dispose();
    _pays.dispose();
    _ville.dispose();
    _titre.dispose();
    _profession.dispose();
    _eglise.dispose();
    _contenu.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════
  //  VALIDATION — miroir des règles de l'API web
  // ═════════════════════════════════════════════════════════════════

  String? _validerNom(String? v) {
    final n = v?.trim() ?? '';
    if (n.length < 2) return 'Indiquez votre nom complet';
    if (n.length > 80) return '80 caractères maximum';
    return null;
  }

  String? _validerEmail(String? v) {
    final e = v?.trim() ?? '';
    if (e.isEmpty) return null; // facultatif
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(e)) {
      return 'Adresse email invalide';
    }
    return null;
  }

  String? _validerTitre(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 3) return 'Donnez un titre à votre témoignage';
    if (t.length > 120) return '120 caractères maximum';
    return null;
  }

  String? _validerContenu(String? v) {
    final c = v?.trim() ?? '';
    if (c.length < _kContenuMin) {
      return 'Racontez votre témoignage en au moins $_kContenuMin caractères';
    }
    if (c.length > _kContenuMax) return '$_kContenuMax caractères maximum';
    return null;
  }

  // ═════════════════════════════════════════════════════════════════
  //  NOTE VOCALE — enregistrement de durée ILLIMITÉE
  // ═════════════════════════════════════════════════════════════════

  String _formaterDuree(int secondes) {
    final h = secondes ~/ 3600;
    final m = (secondes % 3600) ~/ 60;
    final s = secondes % 60;
    if (h > 0) {
      return '$h:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _supprimerFichierAudio() {
    if (_cheminAudio != null) {
      try {
        final f = File(_cheminAudio!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {
        /* fichier temporaire — pas grave */
      }
    }
  }

  Future<void> _basculerEnregistrement() async {
    if (_enregistrementEnCours) {
      await _arreterEnregistrement();
      return;
    }
    try {
      if (!await _enregistreur.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Autorisation micro requise pour la note vocale.',
              ),
            ),
          );
        }
        return;
      }
      // On repart d'une note vierge (aperçu + fichier précédent).
      await _lecteurApercu.stop();
      _supprimerFichierAudio();
      if (mounted) setState(() => _lectureApercu = false);

      final dir = Directory.systemTemp;
      _cheminAudio =
          '${dir.path}/temoignage-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _enregistreur.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000),
        path: _cheminAudio!,
      );
      _debutEnregistrement = DateTime.now();
      if (mounted) {
        setState(() {
          _enregistrementEnCours = true;
          _secondesEnregistrees = 0;
        });
      }
      // ⭐ V4.25 — AUCUNE coupure automatique : le compteur tourne tant
      // que le témoin n'arrête pas (durée illimitée demandée).
      _minuteurEnregistrement = Timer.periodic(
        const Duration(seconds: 1),
        (t) {
          if (!mounted || !_enregistrementEnCours) {
            t.cancel();
            return;
          }
          setState(() {
            _secondesEnregistrees =
                DateTime.now().difference(_debutEnregistrement!).inSeconds;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _enregistrementEnCours = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de démarrer l\'enregistrement — '
              'vous pouvez envoyer votre témoignage écrit.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _arreterEnregistrement() async {
    _minuteurEnregistrement?.cancel();
    _minuteurEnregistrement = null;
    try {
      await _enregistreur.stop();
    } catch (_) {
      /* ignore */
    }
    if (mounted) setState(() => _enregistrementEnCours = false);
  }

  /// Écoute de l'aperçu avant l'envoi (fichier local).
  Future<void> _basculerApercu() async {
    if (_cheminAudio == null) return;
    if (_lectureApercu) {
      await _lecteurApercu.pause();
      if (mounted) setState(() => _lectureApercu = false);
      return;
    }
    try {
      await _lecteurApercu.play(DeviceFileSource(_cheminAudio!));
      if (mounted) setState(() => _lectureApercu = true);
      _lecteurApercu.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _lectureApercu = false);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lecture de l\'aperçu impossible.')),
        );
      }
    }
  }

  Future<void> _supprimerNoteVocale() async {
    _minuteurEnregistrement?.cancel();
    try {
      if (await _enregistreur.isRecording()) {
        await _enregistreur.stop();
      }
    } catch (_) {
      /* ignore */
    }
    await _lecteurApercu.stop();
    _supprimerFichierAudio();
    if (mounted) {
      setState(() {
        _enregistrementEnCours = false;
        _lectureApercu = false;
        _cheminAudio = null;
        _secondesEnregistrees = 0;
      });
    }
  }

  // ═════════════════════════════════════════════════════════════════
  //  NAVIGATION ENTRE ÉTAPES
  // ═════════════════════════════════════════════════════════════════

  void _versEtape2() {
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _etape = 2);
  }

  // ═════════════════════════════════════════════════════════════════
  //  ENVOI
  // ═════════════════════════════════════════════════════════════════

  /// ⭐ V2.18 — Upload DIRECT de la note vocale vers R2 (presign → PUT).
  /// Retourne null si aucune note, ou un message d'erreur explicite.
  Future<String?> _uploaderNoteVocale() async {
    if (_cheminAudio == null) return null;
    final fichier = File(_cheminAudio!);
    if (!fichier.existsSync() || fichier.lengthSync() < 1024) return null;

    setState(() => _envoiAudio = true);
    try {
      // 1) URL pré-signée (aucun octet audio ne transite par le serveur).
      final presign = await ApiClient.instance.postJson(
        '/api/temoignages-croyants/audio-presign',
        body: {'contentType': 'audio/mp4'},
      );
      if (presign is! Map ||
          presign['uploadUrl'] is! String ||
          presign['publicUrl'] is! String) {
        return 'Envoi de la note vocale impossible — réessayez, ou '
            'supprimez-la pour envoyer le texte seul.';
      }

      // 2) PUT binaire direct vers Cloudflare R2 (durée illimitée).
      final octets = await fichier.readAsBytes();
      await ApiClient.instance.putOctetsVersUrl(
        presign['uploadUrl'] as String,
        octets,
        'audio/mp4',
      );

      // 3) Métadonnées prêtes pour le POST final.
      _audioUrlTeleverse = presign['publicUrl'] as String;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Envoi de la note vocale impossible — réessayez, ou '
          'supprimez-la pour envoyer le texte seul.';
    } finally {
      if (mounted) setState(() => _envoiAudio = false);
    }
  }

  String? _audioUrlTeleverse;

  Future<void> _envoyer() async {
    if (!_formulaire.currentState!.validate()) return;
    if (!_consentement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez accepter la relecture pastorale avant l\'envoi.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!Connectivite.instance.enLigne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L\'envoi d\'un témoignage nécessite Internet — '
            'votre formulaire reste rempli, reconnectez-vous puis envoyez.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      // ⭐ V2.18 — 1) Note vocale d'abord (upload direct R2).
      _audioUrlTeleverse = null;
      final erreurAudio = await _uploaderNoteVocale();
      if (erreurAudio != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(erreurAudio),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // 2) Envoi du témoignage (texte + métadonnées du vocal).
      final corps = <String, dynamic>{
        'nom': _nom.text.trim(),
        'email': _email.text.trim(),
        'telephone': _telephone.text.trim(),
        'pays': _pays.text.trim(),
        'ville': _ville.text.trim(),
        'profession': _profession.text.trim(),
        'eglise': _eglise.text.trim(),
        'categorie': _categorie,
        'titre': _titre.text.trim(),
        'contenu': _contenu.text.trim(),
        'consentement': true,
        'siteWeb': '', // honeypot anti-robots (comme le web)
      };
      if (_audioUrlTeleverse != null) {
        corps['audioUrl'] = _audioUrlTeleverse;
        corps['audioDuree'] = _secondesEnregistrees;
        corps['audioMime'] = 'audio/mp4';
        corps['audioTaille'] = File(_cheminAudio!).lengthSync();
      }

      final reponse = await ApiClient.instance.postJson(
        '/api/temoignages-croyants',
        body: corps,
      );
      if (!mounted) return;
      if (reponse is Map && reponse['ok'] == true) {
        setState(() => _etape = 3);
      } else {
        throw const ApiException('Réponse inattendue du serveur.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Envoi impossible — réessayez dans un instant.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  //  UI
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Partager votre témoignage',
          style: TextStyle(
            color: AppColors.encre,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formulaire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          children: [
            _enteteEtape(),
            const SizedBox(height: 20),
            if (_etape == 1)
              _etape1()
            else if (_etape == 2)
              _etape2()
            else
              // Étape 3 — reçu : le ListView garde le padding, on centre.
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: RecuTemoignage(
                  onFermer: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bandeau d'en-tête : pastilles de progression + libellé.
  Widget _enteteEtape() {
    final libelles = {
      1: 'Étape 1 sur 2 · Vous',
      2: 'Étape 2 sur 2 · Votre témoignage',
      3: 'Reçu',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var n = 1; n <= 3; n++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 6,
                width: _etape >= n ? 32 : 14,
                decoration: BoxDecoration(
                  color: _etape >= n ? AppColors.or : AppColors.pourpreClair,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (n < 3) const SizedBox(width: 5),
            ],
            const SizedBox(width: 10),
            Text(
              libelles[_etape] ?? '',
              style: const TextStyle(
                color: AppColors.encreEteinte,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── ÉTAPE 1 — VOUS PERSONNELLEMENT ──────────────────────────────

  Widget _etape1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pourpre,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'INFORMATIONS PERSONNELLES',
            style: TextStyle(
              color: AppColors.orPastel,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Dites-nous qui vous êtes.',
          style: TextStyle(
            color: AppColors.encre,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ces informations servent uniquement à la relecture pastorale — '
          'votre email et votre téléphone ne seront jamais publiés.',
          style: TextStyle(
            color: AppColors.encreSecondaire,
            fontSize: 13,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
        _champ(
          _nom,
          'Nom complet *',
          Icons.person_outline,
          'Ex. Marie K.',
          validateur: _validerNom,
          maxLongueur: 80,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _champ(
                _email,
                'Email',
                Icons.alternate_email,
                'vous@exemple.com',
                type: TextInputType.emailAddress,
                validateur: _validerEmail,
                maxLongueur: 120,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _champ(
                _telephone,
                'Téléphone',
                Icons.phone_outlined,
                '+229…',
                type: TextInputType.phone,
                maxLongueur: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _champ(_pays, 'Pays', Icons.public, 'Ex. Bénin',
                  maxLongueur: 60),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _champ(
                  _ville, 'Ville', Icons.location_city_outlined, 'Ex. Cotonou',
                  maxLongueur: 60),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.or,
            foregroundColor: AppColors.nuit,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _versEtape2,
          child: const Text(
            'Continuer vers le témoignage',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 2 — VOTRE TÉMOIGNAGE ──────────────────────────────────

  Widget _etape2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pourpre,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'VOTRE TÉMOIGNAGE',
            style: TextStyle(
              color: AppColors.orPastel,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Racontez ce que Dieu a fait.',
          style: TextStyle(
            color: AppColors.encre,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 18),
        _champ(
          _titre,
          'Titre de votre témoignage *',
          Icons.auto_awesome,
          'Ex. Délivré après dix ans de ténèbres',
          validateur: _validerTitre,
          maxLongueur: 120,
        ),
        const SizedBox(height: 14),
        const Text(
          'CATÉGORIE',
          style: TextStyle(
            color: AppColors.orPastel,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _kCategories.entries
              .map((e) => _puceCategorie(e.key, e.value))
              .toList(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _champ(_profession, 'Profession', Icons.work_outline,
                  'Ex. Enseignante',
                  maxLongueur: 80),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _champ(_eglise, 'Église locale', Icons.church_outlined,
                  'Ex. Assemblée de…',
                  maxLongueur: 120),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _champ(
          _contenu,
          'Votre récit *',
          Icons.notes_outlined,
          'Ce que le Seigneur a fait dans votre vie, comment vous '
              'l\'avez rencontré, ce qui a changé…',
          multiLignes: true,
          validateur: _validerContenu,
          maxLongueur: _kContenuMax,
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _contenu,
          builder: (context, valeur, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Minimum 30 caractères.',
                style: TextStyle(color: AppColors.encreEteinte, fontSize: 11),
              ),
              Text(
                '${valeur.text.length} / $_kContenuMax',
                style: TextStyle(
                  color: valeur.text.length > _kContenuMax - 500
                      ? AppColors.danger
                      : AppColors.encreEteinte,
                  fontSize: 11,
                  fontWeight: valeur.text.length > _kContenuMax - 500
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── ⭐ V2.18 — NOTE VOCALE (durée illimitée) ──
        _sectionNoteVocale(),
        const SizedBox(height: 14),

        // ── Consentement à la relecture pastorale ──
        InkWell(
          onTap: () => setState(() => _consentement = !_consentement),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pourpre,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _consentement ? AppColors.or : AppColors.pourpreClair,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _consentement
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: _consentement ? AppColors.or : AppColors.encreEteinte,
                  size: 21,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'J\'accepte que mon témoignage (récit et note vocale) '
                    'soit relu par l\'équipe pastorale avant publication sur '
                    'le site et l\'app du Mouvement Christ Libère. Je '
                    'confirme que ce récit est vrai et personnel.',
                    style: TextStyle(
                      color: AppColors.encreSecondaire,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.pourpreClair),
                foregroundColor: AppColors.encreSecondaire,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              ),
              onPressed: () => setState(() => _etape = 1),
              child: const Text('Retour'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed:
                    _envoi || _enregistrementEnCours ? null : _envoyer,
                child: _envoi
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.nuit,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _envoiAudio
                                  ? 'Envoi de la note vocale…'
                                  : 'Envoi en cours…',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Envoyer pour validation',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── SECTION NOTE VOCALE — 3 états (vide / en cours / prête) ────

  Widget _sectionNoteVocale() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pourpreClair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none, color: AppColors.or, size: 18),
              const SizedBox(width: 8),
              const Text(
                'VOTRE VOIX',
                style: TextStyle(
                  color: AppColors.orPastel,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (!_enregistrementEnCours && _cheminAudio == null)
                const Text(
                  'Facultatif · sans limite de durée',
                  style: TextStyle(
                    color: AppColors.encreEteinte,
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // État 1 — rien : proposer l'enregistrement.
          if (!_enregistrementEnCours && _cheminAudio == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.or),
                foregroundColor: AppColors.or,
              ),
              onPressed: _basculerEnregistrement,
              icon: const Icon(Icons.mic, size: 20),
              label: const Text(
                'Enregistrer un vocal de mon témoignage',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),

          // État 2 — enregistrement en cours : compteur illimité + stop.
          if (_enregistrementEnCours) ...[
            Row(
              children: [
                // Point rouge pulsant.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, v, _) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: v),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Enregistrement…',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _formaterDuree(_secondesEnregistrees),
                  style: const TextStyle(
                    color: AppColors.encre,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppColors.fond,
                foregroundColor: AppColors.or,
              ),
              onPressed: _arreterEnregistrement,
              icon: const Icon(Icons.stop_circle, size: 20),
              label: const Text(
                'Arrêter l\'enregistrement',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],

          // État 3 — vocal prêt : aperçu, ré-enregistrer, supprimer.
          if (!_enregistrementEnCours && _cheminAudio != null) ...[
            Row(
              children: [
                GestureDetector(
                  onTap: _basculerApercu,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.or,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _lectureApercu ? Icons.pause : Icons.play_arrow,
                      color: AppColors.nuit,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vocal prêt · ${_formaterDuree(_secondesEnregistrees)}',
                        style: const TextStyle(
                          color: AppColors.encre,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Écoutez-le avant d\'envoyer.',
                        style: TextStyle(
                          color: AppColors.encreEteinte,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.or),
                      foregroundColor: AppColors.or,
                    ),
                    onPressed: _basculerEnregistrement,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text(
                      'Ré-enregistrer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: _supprimerNoteVocale,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text(
                      'Supprimer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Puce de sélection de catégorie (or quand active).
  Widget _puceCategorie(String cle, String libelle) {
    final active = _categorie == cle;
    return GestureDetector(
      onTap: () => setState(() => _categorie = cle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.or : AppColors.pourpre,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.or : AppColors.pourpreClair,
          ),
        ),
        child: Text(
          libelle,
          style: TextStyle(
            color: active ? AppColors.nuit : AppColors.encreSecondaire,
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  CHAMPS — même décorum que l'intercession
  // ═════════════════════════════════════════════════════════════════

  InputDecoration _decoration(String libelle) => InputDecoration(
        labelText: libelle,
        labelStyle: const TextStyle(color: AppColors.orPastel, fontSize: 12.5),
        filled: true,
        fillColor: AppColors.carte,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pourpreClair),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pourpreClair),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.or),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11),
      );

  Widget _champ(
    TextEditingController controleur,
    String libelle,
    IconData icone,
    String indice, {
    bool multiLignes = false,
    TextInputType type = TextInputType.text,
    int? maxLongueur,
    String? Function(String?)? validateur,
  }) =>
      TextFormField(
        controller: controleur,
        keyboardType: type,
        maxLines: multiLignes ? 6 : 1,
        minLines: multiLignes ? 4 : 1,
        maxLength: maxLongueur,
        validator: validateur,
        style: const TextStyle(color: AppColors.encre, fontSize: 14),
        decoration: _decoration(libelle).copyWith(
          prefixIcon: icone == Icons.notes_outlined && multiLignes
              ? null
              : Icon(icone, color: AppColors.or, size: 19),
          hintText: indice,
          hintStyle:
              const TextStyle(color: AppColors.encreEteinte, fontSize: 12.5),
          counterText: '',
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  ÉTAPE 3 — REÇU DE CONFIRMATION (affichée par l'écran parent quand
//  _etape == 3 ; définie ici pour garder le parcours en un fichier)
// ═══════════════════════════════════════════════════════════════════

/// Écran de remerciement après un envoi réussi.
class RecuTemoignage extends StatelessWidget {
  final VoidCallback onFermer;

  const RecuTemoignage({super.key, required this.onFermer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.or.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 44,
                color: AppColors.or,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Merci pour votre témoignage !',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.encre,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'L\'équipe pastorale va le relire attentivement. Une fois '
              'validé, il apparaîtra dans la section « Vies transformées » '
              '— pour l\'édification de toute la communauté.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.encreSecondaire,
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
              ),
              onPressed: onFermer,
              child: const Text(
                'Fermer',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

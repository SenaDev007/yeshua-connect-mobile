/// ⭐ V2.0 — INTERCESSION : dépôt d'une demande de prière
/// (miroir de la page /intercession du site, V3.32/V3.30 web).
///
/// Formulaire complet : nom complet, pays (requis — « savoir d'où vient
/// la demande »), ville, téléphone, email, catégorie, sujet, description
/// ET NOTE VOCALE FACULTATIVE (jusqu'à 2 minutes — « que ça soit par
/// texte, que ça soit par note vocale »).
///
/// Confidentialité identique au web : la demande arrive DIRECTEMENT
/// dans le back-office et le canal dédié « Sujets de prière » — elle
/// n'est jamais publique.
///
/// L'ENVOI exige la connexion (dépôt) ; le formulaire reste remplissable
/// hors ligne avec un message explicite.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

class IntercessionScreen extends ConsumerStatefulWidget {
  const IntercessionScreen({super.key});

  @override
  ConsumerState<IntercessionScreen> createState() => _IntercessionScreenState();
}

class _IntercessionScreenState extends ConsumerState<IntercessionScreen> {
  final _formulaire = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _pays = TextEditingController();
  final _ville = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _sujet = TextEditingController();
  final _description = TextEditingController();

  String _categorie = 'general';
  bool _urgente = false;

  // ── Note vocale (record — même limite de 2 min que le web) ──
  final AudioRecorder _enregistreur = AudioRecorder();
  bool _enregistrementEnCours = false;
  int _secondesEnregistrees = 0;
  String? _cheminAudio;
  DateTime? _debutEnregistrement;
  Timer? _minuteurEnregistrement;

  bool _envoi = false;

  static const _categories = {
    'general': 'Général',
    'sante': 'Santé',
    'famille': 'Famille',
    'spiritual': 'Spirituel',
    'action_graces': 'Action de grâces',
  };

  @override
  void dispose() {
    _minuteurEnregistrement?.cancel();
    _nom.dispose();
    _pays.dispose();
    _ville.dispose();
    _telephone.dispose();
    _email.dispose();
    _sujet.dispose();
    _description.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════
  //  ENREGISTREMENT DE LA NOTE VOCALE
  // ═════════════════════════════════════════════════════════════════

  Future<void> _basculerEnregistrement() async {
    if (_enregistrementEnCours) {
      await _enregistreur.stop();
      if (mounted) setState(() => _enregistrementEnCours = false);
      return;
    }
    try {
      if (!await _enregistreur.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Autorisation micro requise pour la note vocale.'),
            ),
          );
        }
        return;
      }
      final dir = Directory.systemTemp;
      _cheminAudio =
          '${dir.path}/intercession-${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      // Compteur + coupure automatique à 2 minutes (limite web).
      _minuteurEnregistrement = Timer.periodic(
        const Duration(seconds: 1),
        (t) {
          if (!mounted || !_enregistrementEnCours) {
            t.cancel();
            return;
          }
          final ecoule =
              DateTime.now().difference(_debutEnregistrement!).inSeconds;
          setState(() => _secondesEnregistrees = ecoule);
          if (ecoule >= 120) {
            t.cancel();
            _basculerEnregistrement();
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _enregistrementEnCours = false);
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════
  //  ENVOI
  // ═════════════════════════════════════════════════════════════════

  Future<void> _envoyer() async {
    if (!_formulaire.currentState!.validate()) return;

    if (!Connectivite.instance.enLigne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L\'envoi d\'une demande de prière nécessite Internet — '
            'votre formulaire reste rempli, reconnectez-vous puis envoyez.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      dynamic reponse;
      if (_cheminAudio != null && File(_cheminAudio!).existsSync()) {
        // ── Multipart (texte + note vocale) — même format que le web ──
        final fichier = await MultipartFile.fromFile(
          _cheminAudio!,
          filename: 'note-vocale.m4a',
          contentType: DioMediaType.parse('audio/mp4'),
        );
        final form = FormData.fromMap({
          'auteur': _nom.text.trim(),
          'pays': _pays.text.trim(),
          'ville': _ville.text.trim(),
          'telephone': _telephone.text.trim(),
          'email': _email.text.trim(),
          'sujet': _sujet.text.trim(),
          'description': _description.text.trim(),
          'categorie': _categorie,
          'isUrgent': _urgente ? 'true' : 'false',
          'audio': fichier,
          'audioDuration': _secondesEnregistrees.toString(),
        });
        reponse = await ApiClient.instance.postFormJson('/api/intercession', form);
      } else {
        // ── JSON historique (sans note vocale) ──
        reponse = await ApiClient.instance.postJson('/api/intercession', body: {
          'auteur': _nom.text.trim(),
          'pays': _pays.text.trim(),
          'ville': _ville.text.trim(),
          'telephone': _telephone.text.trim(),
          'email': _email.text.trim(),
          'sujet': _sujet.text.trim(),
          'description': _description.text.trim(),
          'categorie': _categorie,
          'isUrgent': _urgente,
        });
      }

      if (!mounted) return;
      if (reponse is Map && (reponse['success'] == true || reponse['id'] != null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre demande a bien été transmise à l\'équipe d\'intercession. '
              'Que Dieu vous réponde selon sa volonté.',
            ),
            duration: Duration(seconds: 5),
            backgroundColor: AppColors.succes,
          ),
        );
        Navigator.of(context).pop();
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
            content: Text('Envoi impossible — réessayez.'),
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
    final contenu = ref.watch(contenuProvider);
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Intercession',
          style: TextStyle(color: AppColors.texte, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          HeroEnTete(hero: contenu.hero('intercession'), hauteur: 140),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              child: Form(
                key: _formulaire,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Déposez votre demande de prière — elle arrive '
                      'directement à l\'équipe d\'intercession du Mouvement, '
                      'en toute confidentialité.',
                      style: TextStyle(
                        color: AppColors.texteSecondaire,
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _champ(_nom, 'Nom complet *', Icons.person_outline,
                        'Votre nom complet'),
                    const SizedBox(height: 12),
                    _champ(_pays, 'Pays *', Icons.public_outlined,
                        'Ex. : Bénin, France, Côte d\'Ivoire…'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _champ(_ville, 'Ville', Icons.location_city_outlined,
                              'Votre ville'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _champ(_telephone, 'Téléphone', Icons.phone_outlined,
                              '+229…'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _champ(_email, 'Email', Icons.alternate_email, 'vous@exemple.com',
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    // ── Catégorie ──
                    DropdownButtonFormField<String>(
                      initialValue: _categorie,
                      dropdownColor: AppColors.pourpre,
                      decoration: _decoration('Catégorie'),
                      style: const TextStyle(color: AppColors.texte, fontSize: 14),
                      items: _categories.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categorie = v ?? 'general'),
                    ),
                    const SizedBox(height: 12),
                    _champ(_sujet, 'Sujet *', Icons.topic_outlined,
                        'Résumé court de votre demande',
                        maxLongueur: 200),
                    const SizedBox(height: 12),
                    _champ(
                      _description,
                      _cheminAudio != null
                          ? 'Description (facultative — votre note vocale sera transmise)'
                          : 'Description *',
                      Icons.notes_outlined,
                      'Décrivez votre demande…',
                      multiLignes: true,
                    ),
                    const SizedBox(height: 16),
                    // ── Note vocale ──
                    _CarteNoteVocale(
                      enCours: _enregistrementEnCours,
                      secondes: _secondesEnregistrees,
                      aUnAudio: _cheminAudio != null,
                      onBasculer: _basculerEnregistrement,
                      onSupprimer: () => setState(() => _cheminAudio = null),
                    ),
                    const SizedBox(height: 14),
                    // ── Urgence ──
                    SwitchListTile(
                      value: _urgente,
                      onChanged: (v) => setState(() => _urgente = v),
                      activeThumbColor: AppColors.or,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Demande urgente',
                        style: TextStyle(color: AppColors.texte, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Traitée en priorité par l\'équipe',
                        style: TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.or,
                        foregroundColor: AppColors.nuit,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _envoi ? null : _envoyer,
                      child: _envoi
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.nuit,
                              ),
                            )
                          : const Text(
                              'Envoyer ma demande',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
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

  InputDecoration _decoration(String libelle) => InputDecoration(
        labelText: libelle,
        labelStyle: const TextStyle(color: AppColors.orPastel, fontSize: 12.5),
        filled: true,
        fillColor: AppColors.pourpre,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
  }) =>
      TextFormField(
        controller: controleur,
        keyboardType: type,
        maxLines: multiLignes ? 5 : 1,
        minLines: multiLignes ? 3 : 1,
        maxLength: maxLongueur,
        style: const TextStyle(color: AppColors.texte, fontSize: 14),
        decoration: _decoration(libelle).copyWith(
          prefixIcon: icone == Icons.notes_outlined && multiLignes
              ? null
              : Icon(icone, color: AppColors.or, size: 19),
          hintText: indice,
          hintStyle: const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
        ),
        validator: (v) {
          if (libelle.endsWith('*') && (v == null || v.trim().isEmpty)) {
            return 'Ce champ est requis';
          }
          if (libelle.startsWith('Email') && v != null && v.isNotEmpty) {
            final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v);
            if (!ok) return 'Adresse email invalide';
          }
          if (libelle.startsWith('Téléphone') && v != null && v.isNotEmpty) {
            final nettoyye = v.replaceAll(RegExp(r'[\s().-]'), '');
            if (!RegExp(r'^\+?\d{6,20}$').hasMatch(nettoyye)) {
              return 'Numéro invalide (ou laissez vide)';
            }
          }
          return null;
        },
      );
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE NOTE VOCALE
// ═══════════════════════════════════════════════════════════════════

class _CarteNoteVocale extends StatelessWidget {
  final bool enCours;
  final int secondes;
  final bool aUnAudio;
  final VoidCallback onBasculer;
  final VoidCallback onSupprimer;

  const _CarteNoteVocale({
    required this.enCours,
    required this.secondes,
    required this.aUnAudio,
    required this.onBasculer,
    required this.onSupprimer,
  });

  static String _duree(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enCours ? AppColors.danger : AppColors.pourpreClair,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBasculer,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enCours ? AppColors.danger : AppColors.or,
                shape: BoxShape.circle,
              ),
              child: Icon(
                enCours ? Icons.stop : Icons.mic_none,
                color: AppColors.nuit,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enCours
                      ? 'Enregistrement… ${_duree(secondes)} / 02:00'
                      : aUnAudio
                          ? 'Note vocale prête (${_duree(secondes)})'
                          : 'Note vocale (facultatif)',
                  style: TextStyle(
                    color: enCours ? AppColors.danger : AppColors.texte,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enCours
                      ? 'Touchez le bouton pour arrêter'
                      : aUnAudio
                          ? 'Transmise avec votre demande'
                          : 'Exprimez-vous librement à la voix (2 minutes max)',
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (aUnAudio && !enCours)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.texteSecondaire),
              onPressed: onSupprimer,
            ),
        ],
      ),
    );
  }
}

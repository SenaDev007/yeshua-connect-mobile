/// ⭐ V2.0 — DEMANDER UN RENDEZ-VOUS (miroir de la page /rendez-vous, V3.66+ web).
///
/// Entrée publique du secrétariat : « quand quelqu'un veut rencontrer le
/// pasteur Kongo ou la sœur Afrika, c'est par le secrétaire ». La demande
/// atterrit directement dans le registre du secrétariat au statut RECUE
/// (source « SITE » — pré-remplie, sans ré-éditer).
///
/// Un CODE DE SUIVI est renvoyé : la demanderesse ou le demandeur peut
/// consulter l'avancement sur le site /rendez-vous/suivi.
///
/// L'ENVOI exige la connexion ; le formulaire reste remplissable hors
/// ligne avec un message explicite.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

class RendezVousScreen extends ConsumerStatefulWidget {
  const RendezVousScreen({super.key});

  @override
  ConsumerState<RendezVousScreen> createState() => _RendezVousScreenState();
}

class _RendezVousScreenState extends ConsumerState<RendezVousScreen> {
  final _formulaire = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _contact = TextEditingController();
  final _objet = TextEditingController();
  final _message = TextEditingController();
  final _pays = TextEditingController();
  final _ville = TextEditingController();

  String _serviteur = 'afrika';
  String _urgence = 'normale';
  bool _envoi = false;
  String? _codeSuivi;

  static const _urgences = {
    'normale': 'Normale',
    'elevee': 'Élevée',
    'urgente': 'Urgente',
  };

  @override
  void dispose() {
    _nom.dispose();
    _contact.dispose();
    _objet.dispose();
    _message.dispose();
    _pays.dispose();
    _ville.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_formulaire.currentState!.validate()) return;

    if (!Connectivite.instance.enLigne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L\'envoi d\'une demande nécessite Internet — votre formulaire '
            'reste rempli, reconnectez-vous puis envoyez.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      final reponse = await ApiClient.instance.postJson(
        '/api/rendez-vous',
        body: {
          'requesterName': _nom.text.trim(),
          'contact': _contact.text.trim(),
          'servantCode': _serviteur,
          'subject': _objet.text.trim(),
          'message': _message.text.trim(),
          'urgency': _urgence,
          'country': _pays.text.trim(),
          'city': _ville.text.trim(),
          'site': '', // honeypot vide (humain)
        },
      );
      if (!mounted) return;
      if (reponse is Map && reponse['success'] == true) {
        setState(() => _codeSuivi = reponse['codeSuivi'] as String? ?? '');
      } else {
        _erreur('La demande n\'a pas pu être enregistrée — réessayez.');
      }
    } on ApiException catch (e) {
      _erreur(e.message);
    } catch (_) {
      _erreur('Envoi impossible — réessayez.');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _erreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  UI
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final contenu = ref.watch(contenuProvider);
    final serviteurs = contenu.serviteurs;

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Demander un rendez-vous',
          style: TextStyle(color: AppColors.texte, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          HeroEnTete(hero: contenu.hero('rendez-vous'), hauteur: 140),
          Expanded(
            child: _codeSuivi != null
                ? _Confirmation(codeSuivi: _codeSuivi!)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                    child: Form(
                      key: _formulaire,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Souhaitez-vous rencontrer Afrika ou le Pasteur '
                            'Kongo ? Votre demande passe par le secrétariat du '
                            'Mouvement : la secrétaire l\'examine, la transmet '
                            'au serviteur de Dieu concerné, puis vous répond.',
                            style: TextStyle(
                              color: AppColors.texteSecondaire,
                              fontSize: 13.5,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // ── Serviteur ──
                          if (serviteurs.isNotEmpty)
                            Row(
                              children: serviteurs
                                  .map((s) => Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: s == serviteurs.last ? 0 : 10,
                                          ),
                                          child: GestureDetector(
                                            onTap: () =>
                                                setState(() => _serviteur = s.code),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _serviteur == s.code
                                                    ? AppColors.or.withValues(alpha: 0.14)
                                                    : AppColors.pourpre,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _serviteur == s.code
                                                      ? AppColors.or
                                                      : AppColors.pourpreClair,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    s.nomCourt,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _serviteur == s.code
                                                          ? AppColors.or
                                                          : AppColors.texte,
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          const SizedBox(height: 14),
                          _champ(_nom, 'Votre nom *', Icons.person_outline, 'Nom complet'),
                          const SizedBox(height: 12),
                          _champ(
                            _contact,
                            'Contact *',
                            Icons.contact_page_outlined,
                            'Téléphone (WhatsApp) ou email',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _champ(_pays, 'Pays', Icons.public_outlined, 'Votre pays'),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _champ(
                                  _ville,
                                  'Ville',
                                  Icons.location_city_outlined,
                                  'Votre ville',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _champ(_objet, 'Objet *', Icons.topic_outlined,
                              'Motif de la rencontre', maxLongueur: 200),
                          const SizedBox(height: 12),
                          _champ(
                            _message,
                            'Message *',
                            Icons.notes_outlined,
                            'Précisez votre demande…',
                            multiLignes: true,
                          ),
                          const SizedBox(height: 14),
                          // ── Urgence ──
                          Wrap(
                            spacing: 8,
                            children: _urgences.entries
                                .map((e) => PuceFiltre(
                                      libelle: e.value,
                                      actif: _urgence == e.key,
                                      onTap: () => setState(() => _urgence = e.key),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 20),
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
      );

  Widget _champ(
    TextEditingController controleur,
    String libelle,
    IconData icone,
    String indice, {
    bool multiLignes = false,
    int? maxLongueur,
  }) =>
      TextFormField(
        controller: controleur,
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
        validator: (v) =>
            (libelle.endsWith('*') && (v == null || v.trim().isEmpty))
                ? 'Ce champ est requis'
                : null,
      );
}

// ═══════════════════════════════════════════════════════════════════
//  ÉCRAN DE CONFIRMATION (code de suivi)
// ═══════════════════════════════════════════════════════════════════

class _Confirmation extends StatelessWidget {
  final String codeSuivi;

  const _Confirmation({required this.codeSuivi});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.succes.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.succes, size: 46),
            ),
            const SizedBox(height: 18),
            const Text(
              'Demande reçue',
              style: TextStyle(
                color: AppColors.texte,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Votre demande a bien été transmise au secrétariat du Mouvement '
              'Christ Libère. La secrétaire l\'examinera et la transmettra au '
              'serviteur de Dieu concerné.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.texteSecondaire,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            if (codeSuivi.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'CODE DE SUIVI — conservez-le',
                style: TextStyle(
                  color: AppColors.or,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.pourpre,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.or.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      codeSuivi,
                      style: const TextStyle(
                        color: AppColors.or,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Copier',
                      icon: const Icon(Icons.copy, size: 16, color: AppColors.orPastel),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: codeSuivi));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copié.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Il permet de suivre l\'avancement de votre demande sur le site :\n'
                'www.mouvementchristlibere.com/rendez-vous/suivi',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.texteEteint, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

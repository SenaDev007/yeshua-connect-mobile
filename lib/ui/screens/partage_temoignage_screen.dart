/// ⭐ V2.17 — PARTAGE DE TÉMOIGNAGE « VIE TRANSFORMÉE »
/// (miroir de la modale « Partager votre témoignage » de la landing web,
/// V3.100/V4.15 — même API, mêmes règles de validation).
///
/// Le croyant raconte ce que Dieu a fait dans sa vie en DEUX étapes :
///   Étape 1 — VOUS PERSONNELLEMENT : nom, email, téléphone, pays, ville
///   (le moyen d'être recontacté — JAMAIS publié) ;
///   Étape 2 — VOTRE TÉMOIGNAGE : titre, catégorie, profession, église,
///   récit complet, consentement à la relecture pastorale.
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

import 'package:flutter/material.dart';

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

const int _kContenuMax = 6000;
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

  /// 1 = vous · 2 = témoignage · 3 = reçu de confirmation.
  int _etape = 1;
  bool _envoi = false;

  @override
  void dispose() {
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
  //  NAVIGATION ENTRE ÉTAPES
  // ═════════════════════════════════════════════════════════════════

  void _versEtape2() {
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _etape = 2);
  }

  // ═════════════════════════════════════════════════════════════════
  //  ENVOI
  // ═════════════════════════════════════════════════════════════════

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
      final reponse = await ApiClient.instance.postJson(
        '/api/temoignages-croyants',
        body: {
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
        },
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
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Partager votre témoignage',
          style: TextStyle(
            color: AppColors.texte,
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
                color: AppColors.texteEteint,
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
            color: AppColors.texte,
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
            color: AppColors.texteSecondaire,
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
            color: AppColors.texte,
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
                style: TextStyle(color: AppColors.texteEteint, fontSize: 11),
              ),
              Text(
                '${valeur.text.length} / $_kContenuMax',
                style: TextStyle(
                  color: valeur.text.length > _kContenuMax - 200
                      ? AppColors.danger
                      : AppColors.texteEteint,
                  fontSize: 11,
                  fontWeight: valeur.text.length > _kContenuMax - 200
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
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
                  color: _consentement ? AppColors.or : AppColors.texteEteint,
                  size: 21,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'J\'accepte que mon témoignage soit relu par l\'équipe '
                    'pastorale avant publication sur le site et l\'app du '
                    'Mouvement Christ Libère. Je confirme que ce récit est '
                    'vrai et personnel.',
                    style: TextStyle(
                      color: AppColors.texteSecondaire,
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
                foregroundColor: AppColors.texteSecondaire,
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
            color: active ? AppColors.nuit : AppColors.texteSecondaire,
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
        fillColor: AppColors.pourpre,
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
        style: const TextStyle(color: AppColors.texte, fontSize: 14),
        decoration: _decoration(libelle).copyWith(
          prefixIcon: icone == Icons.notes_outlined && multiLignes
              ? null
              : Icon(icone, color: AppColors.or, size: 19),
          hintText: indice,
          hintStyle:
              const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
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
                color: AppColors.texte,
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
                color: AppColors.texteSecondaire,
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

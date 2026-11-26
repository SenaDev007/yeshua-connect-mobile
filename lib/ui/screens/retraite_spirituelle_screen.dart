/// ⭐ V4.43 — RETRAITE SPIRITUELLE (miroir de la page /retraite-spirituelle).
///
/// Le ministère accueille des retraites spirituelles sur un lieu aménagé
/// en Côte d'Ivoire. Toute personne désireuse de venir passer quelques
/// jours dépose D'ABORD sa demande :
///   · informations identitaires complètes (prénom, nom, contact, pays,
///     ville, adresse, profession, situation matrimoniale, contact
///     d'urgence) ;
///   · séjour souhaité (date d'arrivée facultative, nombre de jours,
///     attentes) ;
///   · photo lisible de sa pièce d'identité ;
///   · capture de la preuve du paiement des frais de dossier (15 000 FCFA).
///
/// Les 2 images sont téléversées DIRECTEMENT vers R2 (presign + PUT —
/// même mécanique que les notes vocales), puis la demande part en JSON
/// vers /api/retreat : elle atterrit dans l'espace de la secrétaire
/// (secretariat.mouvementchristlibere.com → Retraites spirituelles) qui
/// l'examine et recontacte le demandeur. Aucun voyage avant acceptation.
///
/// L'ENVOI exige la connexion ; le formulaire reste remplissable hors
/// ligne avec un message explicite.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';
import '../widgets/contenu_widgets.dart';

class RetraiteSpirituelleScreen extends ConsumerStatefulWidget {
  const RetraiteSpirituelleScreen({super.key});

  @override
  ConsumerState<RetraiteSpirituelleScreen> createState() =>
      _RetraiteSpirituelleScreenState();
}

class _RetraiteSpirituelleScreenState
    extends ConsumerState<RetraiteSpirituelleScreen> {
  final _formulaire = GlobalKey<FormState>();

  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _pays = TextEditingController();
  final _ville = TextEditingController();
  final _adresse = TextEditingController();
  final _profession = TextEditingController();
  final _urgenceContact = TextEditingController();
  final _jours = TextEditingController();
  final _attentes = TextEditingController();

  String _genre = 'NON_PRECISE';
  String _situation = 'Non précisé';
  String _moyenPaiement = 'Orange Money';
  DateTime? _dateArrivee;
  bool _dejaVenu = false;
  bool _certification = false;

  /// Pièce jointe sélectionnée (octets compressés + aperçu mémoire).
  Uint8List? _octetsIdentite;
  Uint8List? _octetsPaiement;

  bool _envoi = false;
  String? _codeSuivi;

  static const _situations = [
    'Non précisé',
    'Célibataire',
    'Marié(e)',
    'Veuf/Veuve',
    'Divorcé(e)',
  ];

  static const _moyensPaiement = [
    'Orange Money',
    'Wave',
    'MTN MoMo',
    'Moov Money',
    'Autre',
  ];

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    _email.dispose();
    _telephone.dispose();
    _pays.dispose();
    _ville.dispose();
    _adresse.dispose();
    _profession.dispose();
    _urgenceContact.dispose();
    _jours.dispose();
    _attentes.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════
  //  Pièces jointes (galerie + compression → octets JPEG)
  // ═════════════════════════════════════════════════════════════════

  Future<void> _choisirImage(bool identite) async {
    try {
      final resultat = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final fichier = resultat?.files.single;
      if (fichier == null || fichier.bytes == null) return;

      // Compression raisonnable : identité/preuve lisible sans dépasser
      // les limites pratiques (min 1280 px de large, qualité 82).
      final compresse = Uint8List.fromList(
        await FlutterImageCompress.compressWithList(
          fichier.bytes!,
          minWidth: 1280,
          quality: 82,
          format: CompressFormat.jpeg,
        ),
      );

      if (!mounted) return;
      setState(() {
        if (identite) {
          _octetsIdentite = compresse;
        } else {
          _octetsPaiement = compresse;
        }
      });
    } catch (_) {
      _erreur('Impossible de charger l\'image — réessayez.');
    }
  }

  /// Téléverse une image DIRECTEMENT vers R2 :
  ///  1. POST /api/retreat/presign → { uploadUrl, publicUrl } ;
  ///  2. PUT des octets vers l'URL pré-signée (aucune limite Vercel).
  Future<String> _televerser(bool identite, Uint8List octets) async {
    final presign = await ApiClient.instance.postJson(
      '/api/retreat/presign',
      body: {
        'kind': identite ? 'identite' : 'paiement',
        'contentType': 'image/jpeg',
      },
    );
    if (presign is! Map ||
        presign['uploadUrl'] is! String ||
        presign['publicUrl'] is! String) {
      throw ApiException('Préparation de l\'upload impossible.');
    }
    await ApiClient.instance.putOctetsVersUrl(
      presign['uploadUrl'] as String,
      octets,
      'image/jpeg',
    );
    return presign['publicUrl'] as String;
  }

  // ═════════════════════════════════════════════════════════════════
  //  Envoi
  // ═════════════════════════════════════════════════════════════════

  Future<void> _envoyer() async {
    if (!_formulaire.currentState!.validate()) return;
    if (_octetsIdentite == null || _octetsPaiement == null) {
      _erreur(
        'Joignez la photo de votre pièce d\'identité ET la capture de votre '
        'preuve de paiement.',
      );
      return;
    }
    if (!_certification) {
      _erreur('Cochez la case de certification avant d\'envoyer.');
      return;
    }

    if (!Connectivite.instance.enLigne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L\'envoi d\'une demande (avec pièces jointes) nécessite '
            'Internet — votre formulaire reste rempli, reconnectez-vous '
            'puis envoyez.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      // 1. Téléversement direct des deux pièces (R2)
      final urlIdentite = await _televerser(true, _octetsIdentite!);
      final urlPaiement = await _televerser(false, _octetsPaiement!);

      // 2. Enregistrement de la demande → espace Secrétariat
      final jours = int.tryParse(_jours.text.trim()) ?? 0;
      final reponse = await ApiClient.instance.postJson(
        '/api/retreat',
        body: {
          'firstName': _prenom.text.trim(),
          'lastName': _nom.text.trim(),
          'gender': _genre,
          'email': _email.text.trim(),
          'phone': _telephone.text.trim(),
          'country': _pays.text.trim(),
          'city': _ville.text.trim(),
          'address': _adresse.text.trim(),
          'profession': _profession.text.trim(),
          'maritalStatus': _situation,
          'emergencyContact': _urgenceContact.text.trim(),
          'arrivalDate': _dateArrivee?.toIso8601String(),
          'numberOfDays': jours,
          'expectations': _attentes.text.trim(),
          'hasBeenBefore': _dejaVenu,
          'paymentMethod': _moyenPaiement,
          'idDocumentUrl': urlIdentite,
          'paymentProofUrl': urlPaiement,
          'source': 'MOBILE',
          'siteWeb': '', // honeypot vide (humain)
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

  Future<void> _choisirDate() async {
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateArrivee ?? aujourdhui.add(const Duration(days: 7)),
      firstDate: aujourdhui,
      lastDate: aujourdhui.add(const Duration(days: 730)),
      builder: (context, enfant) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.or,
            surface: AppColors.pourpre,
          ),
        ),
        child: enfant!,
      ),
    );
    if (choisie != null) setState(() => _dateArrivee = choisie);
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
          'Retraite spirituelle',
          style: TextStyle(
              color: AppColors.encre, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: _codeSuivi != null
          ? _Confirmation(codeSuivi: _codeSuivi!)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              child: Form(
                key: _formulaire,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Un lieu a été aménagé en Côte d\'Ivoire pour accueillir '
                      'toute personne désireuse de passer quelques jours de '
                      'retraite spirituelle. Déposez d\'abord votre demande : '
                      'la secrétaire l\'examine puis vous recontacte. Aucun '
                      'voyage avant acceptation.',
                      style: TextStyle(
                        color: AppColors.encreSecondaire,
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── Identité ──
                    _champ(_prenom, 'Prénom *', Icons.person_outline, 'Votre prénom'),
                    const SizedBox(height: 12),
                    _champ(_nom, 'Nom *', Icons.badge_outlined, 'Votre nom'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _champ(
                            _telephone,
                            'Téléphone / WhatsApp *',
                            Icons.phone_outlined,
                            '+225 …',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _champ(
                            _email,
                            'Email',
                            Icons.alternate_email_outlined,
                            'Facultatif',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ── Genre (puces) ──
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: const [
                          'NON_PRECISE',
                          'FEMME',
                          'HOMME',
                        ]
                            .map((g) => PuceFiltre(
                                  libelle: g == 'NON_PRECISE'
                                      ? 'Genre : non précisé'
                                      : g == 'FEMME'
                                          ? 'Femme'
                                          : 'Homme',
                                  actif: _genre == g,
                                  onTap: () => setState(() => _genre = g),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _champ(
                            _pays,
                            'Pays de résidence *',
                            Icons.public_outlined,
                            'Ex. Côte d\'Ivoire',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _champ(
                            _ville,
                            'Ville d\'origine *',
                            Icons.location_city_outlined,
                            'Ex. Abidjan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _champ(
                      _adresse,
                      'Adresse / quartier',
                      Icons.home_outlined,
                      'Facultatif',
                    ),
                    const SizedBox(height: 12),
                    _champ(
                      _profession,
                      'Profession / occupation',
                      Icons.work_outline,
                      'Facultatif',
                    ),
                    const SizedBox(height: 12),
                    // ── Situation matrimoniale ──
                    _selecteur(
                      libelle: 'Situation matrimoniale',
                      icone: Icons.favorite_outline,
                      valeur: _situation,
                      options: _situations,
                      onChanged: (v) => setState(() => _situation = v!),
                    ),
                    const SizedBox(height: 12),
                    _champ(
                      _urgenceContact,
                      'Personne à contacter en cas d\'urgence',
                      Icons.contact_phone_outlined,
                      'Nom + téléphone (recommandé)',
                    ),
                    const SizedBox(height: 20),
                    // ── Séjour ──
                    _sectionTitre('Votre séjour souhaité', Icons.hotel_outlined),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _choisirDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: AppColors.pourpre,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.pourpreClair),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      color: AppColors.or, size: 19),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _dateArrivee == null
                                          ? 'Date d\'arrivée souhaitée'
                                          : 'Arrivée : ${_dateArrivee!.day}/${_dateArrivee!.month}/${_dateArrivee!.year}',
                                      style: TextStyle(
                                        color: _dateArrivee == null
                                            ? AppColors.encreEteinte
                                            : AppColors.encre,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _champ(
                      _jours,
                      'Nombre de jours *',
                      Icons.timelapse_outlined,
                      'Ex. 7 (entre 1 et 90)',
                      clavier: TextInputType.number,
                      validateur: (v) {
                        final jours = int.tryParse(v?.trim() ?? '');
                        if (jours == null || jours < 1 || jours > 90) {
                          return 'Entre 1 et 90 jours';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _champ(
                      _attentes,
                      'Motif / attentes spirituelles',
                      Icons.notes_outlined,
                      'Pourquoi souhaitez-vous cette retraite ? (facultatif)',
                      multiLignes: true,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _dejaVenu,
                      onChanged: (v) => setState(() => _dejaVenu = v ?? false),
                      activeColor: AppColors.or,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Je suis déjà venu(e) sur le lieu de retraite',
                        style: TextStyle(
                          color: AppColors.encreSecondaire,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Paiement + pièces jointes ──
                    _sectionTitre(
                      'Frais de dossier : 15 000 FCFA',
                      Icons.payments_outlined,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Payez les frais de dossier via Mobile Money ou tout '
                      'autre moyen officiel du ministère, puis joignez la '
                      'capture du reçu. Si vous ne connaissez pas encore les '
                      'coordonnées de paiement, contactez d\'abord la '
                      'secrétaire du ministère.',
                      style: TextStyle(
                        color: AppColors.encreSecondaire,
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _selecteur(
                      libelle: 'Moyen de paiement utilisé',
                      icone: Icons.account_balance_wallet_outlined,
                      valeur: _moyenPaiement,
                      options: _moyensPaiement,
                      onChanged: (v) => setState(() => _moyenPaiement = v!),
                    ),
                    const SizedBox(height: 14),
                    _pieceJointe(
                      titre: 'Pièce d\'identité *',
                      aide: 'Photo lisible de votre CNI, passeport ou '
                          'attestation d\'identité.',
                      octets: _octetsIdentite,
                      onChoisir: () => _choisirImage(true),
                    ),
                    const SizedBox(height: 12),
                    _pieceJointe(
                      titre: 'Preuve de paiement *',
                      aide: 'Capture d\'écran ou photo du reçu des '
                          '15 000 FCFA.',
                      octets: _octetsPaiement,
                      onChoisir: () => _choisirImage(false),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: _certification,
                      onChanged: (v) =>
                          setState(() => _certification = v ?? false),
                      activeColor: AppColors.or,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Je certifie que les informations et pièces fournies '
                        'sont exactes, et j\'attendrai l\'acceptation de la '
                        'secrétaire avant tout déplacement. *',
                        style: TextStyle(
                          color: AppColors.encreSecondaire,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
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
                              'Valider ma demande',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitre(String titre, IconData icone) => Row(
        children: [
          Icon(icone, color: AppColors.or, size: 17),
          const SizedBox(width: 7),
          Text(
            titre,
            style: const TextStyle(
              color: AppColors.orPastel,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );

  Widget _selecteur({
    required String libelle,
    required IconData icone,
    required String valeur,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: valeur,
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
        dropdownColor: AppColors.carte,
        style: const TextStyle(color: AppColors.encre, fontSize: 14),
        icon: const Icon(Icons.expand_more, color: AppColors.or),
        decoration: _decoration(libelle).copyWith(
          prefixIcon: Icon(icone, color: AppColors.or, size: 19),
        ),
      );

  Widget _pieceJointe({
    required String titre,
    required String aide,
    required Uint8List? octets,
    required VoidCallback onChoisir,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.pourpreClair),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: octets != null
                  ? Image.memory(
                      octets,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: AppColors.pourpreClair,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.encreEteinte, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      color: AppColors.encre,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    octets == null ? aide : 'Image prête — appuyez pour changer.',
                    style: const TextStyle(
                      color: AppColors.encreEteinte,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onChoisir,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.or.withValues(alpha: 0.14),
                foregroundColor: AppColors.or,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                octets == null ? 'Choisir' : 'Changer',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  InputDecoration _decoration(String libelle) => InputDecoration(
        labelText: libelle,
        labelStyle: const TextStyle(color: AppColors.orPastel, fontSize: 12.5),
        filled: true,
        fillColor: AppColors.carte,
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
    TextInputType? clavier,
    String? Function(String?)? validateur,
  }) =>
      TextFormField(
        controller: controleur,
        maxLines: multiLignes ? 5 : 1,
        minLines: multiLignes ? 3 : 1,
        maxLength: maxLongueur,
        keyboardType: clavier,
        style: const TextStyle(color: AppColors.encre, fontSize: 14),
        decoration: _decoration(libelle).copyWith(
          prefixIcon: icone == Icons.notes_outlined && multiLignes
              ? null
              : Icon(icone, color: AppColors.or, size: 19),
          hintText: indice,
          hintStyle: const TextStyle(color: AppColors.encreEteinte, fontSize: 12.5),
        ),
        validator: validateur ??
            (v) =>
                (libelle.endsWith('*') && (v == null || v.trim().isEmpty))
                    ? 'Ce champ est requis'
                    : null,
      );
}

// ═════════════════════════════════════════════════════════════════
//  ÉCRAN DE CONFIRMATION (code de suivi RET-XXXXXX)
// ═════════════════════════════════════════════════════════════════

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
              'Demande de retraite reçue',
              style: TextStyle(
                color: AppColors.encre,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Votre dossier (identité, pièces jointes et preuve de paiement) '
              'a été transmis à la secrétaire du ministère. Elle l\'examinera '
              'puis vous contactera au numéro indiqué — soyez disponible sur '
              'WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.encreSecondaire,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.pourpre,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.or.withValues(alpha: 0.4)),
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
                'Citez ce code dans tous vos échanges avec la secrétaire.\n'
                'N\'entreprennez aucun voyage avant l\'acceptation expresse '
                'de votre demande.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.encreEteinte, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

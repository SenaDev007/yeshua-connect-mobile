/// ⭐ V2.0 — CONTRIBUER (miroir de la page /contribuer du site).
///
/// Dons sécurisés par carte bancaire ou Mobile Money (MTN, Orange, Moov,
/// Wave) via FedaPay, ou carte internationale via Paystack : mêmes
/// passerelles que le web — le paiement s'effectue sur la page sécurisée
/// du fournisseur (ouverte dans le navigateur), puis la confirmation
/// revient par webhook signé au back-office.
///
/// L'ENVOI exige la connexion ; le formulaire reste remplissable hors
/// ligne avec un message explicite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

class ContribuerScreen extends ConsumerStatefulWidget {
  const ContribuerScreen({super.key});

  @override
  ConsumerState<ContribuerScreen> createState() => _ContribuerScreenState();
}

class _ContribuerScreenState extends ConsumerState<ContribuerScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _montantLibre = TextEditingController();

  int? _montantChoisi = 5000;
  String _typeDon = 'offrande';
  String _passerelle = 'fedapay';
  bool _envoi = false;

  static const _types = {
    'offrande': 'Offrande',
    'dime': 'Dîme',
    'don': 'Don',
  };
  static const _montantsSuggeres = [1000, 2000, 5000, 10000, 25000, 50000];

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _montantLibre.dispose();
    super.dispose();
  }

  int? get _montantFinal {
    final libre = int.tryParse(_montantLibre.text.trim());
    return _montantLibre.text.trim().isNotEmpty ? libre : _montantChoisi;
  }

  bool get _montantOk {
    final m = _montantFinal;
    return m != null && m >= 100 && m <= 5000000;
  }

  Future<void> _envoyer() async {
    if (!_formulaire.currentState!.validate()) return;
    if (!_montantOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisissez un montant valide (nombre entier, entre 100 et '
            '5 000 000 FCFA).',
          ),
        ),
      );
      return;
    }
    if (!Connectivite.instance.enLigne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le don nécessite Internet — votre formulaire reste rempli, '
            'reconnectez-vous puis touchez « Contribuer ».',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _envoi = true);
    try {
      final reponse = await ApiClient.instance.postJson(
        '/api/dons/initier',
        body: {
          'type_don': _typeDon,
          'montant': _montantFinal,
          'email': _email.text.trim(),
          'nom': _nom.text.trim(),
          'provider': _passerelle,
        },
      );
      if (!mounted) return;
      if (reponse is Map && reponse['paymentUrl'] is String) {
        final url = Uri.tryParse(reponse['paymentUrl'] as String);
        if (url != null) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
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
            content: Text('Initialisation du don impossible — réessayez.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

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
          'Contribuer',
          style: TextStyle(color: AppColors.texte, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          HeroEnTete(hero: contenu.hero('contribuer'), hauteur: 150),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              child: Form(
                key: _formulaire,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '« Que chacun donne comme il l\'a résolu en son cœur, '
                      'sans tristesse ni contrainte ; car Dieu aime celui '
                      'qui donne avec joie. » — 2 Corinthiens 9:7\n\n'
                      'Votre offrande finance la mission : lives, enseignements, '
                      'accompagnement des dispersés et de la communauté.',
                      style: TextStyle(
                        color: AppColors.texteSecondaire,
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── Type de don ──
                    Wrap(
                      spacing: 8,
                      children: _types.entries
                          .map((e) => PuceFiltre(
                                libelle: e.value,
                                actif: _typeDon == e.key,
                                onTap: () => setState(() => _typeDon = e.key),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    // ── Montants suggérés ──
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _montantsSuggeres
                          .map((m) => PuceFiltre(
                                libelle: '${_formatFcfa(m)} FCFA',
                                actif: _montantLibre.text.isEmpty && _montantChoisi == m,
                                onTap: () => setState(() {
                                  _montantLibre.clear();
                                  _montantChoisi = m;
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    // ── Montant libre ──
                    TextFormField(
                      controller: _montantLibre,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.texte, fontSize: 14),
                      decoration: _decoration('Montant libre (FCFA)').copyWith(
                        prefixIcon:
                            const Icon(Icons.payments_outlined, color: AppColors.or, size: 19),
                        hintText: 'Ou saisissez votre montant',
                        hintStyle:
                            const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    _champ(_nom, 'Nom (facultatif)', Icons.person_outline, 'Votre nom'),
                    const SizedBox(height: 12),
                    _champEmail(),
                    const SizedBox(height: 18),
                    // ── Passerelle ──
                    const Text(
                      'MOYEN DE PAIEMENT',
                      style: TextStyle(
                        color: AppColors.or,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CartePasserelle(
                      id: 'fedapay',
                      titre: 'FedaPay',
                      sousTitre: 'Mobile Money (MTN, Orange, Moov, Wave) et '
                          'cartes bancaires régionales',
                      icone: Icons.phone_android,
                      actif: _passerelle == 'fedapay',
                      onSelect: () => setState(() => _passerelle = 'fedapay'),
                    ),
                    const SizedBox(height: 8),
                    _CartePasserelle(
                      id: 'paystack',
                      titre: 'Paystack',
                      sousTitre: 'Cartes bancaires internationales',
                      icone: Icons.credit_card,
                      actif: _passerelle == 'paystack',
                      onSelect: () => setState(() => _passerelle = 'paystack'),
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
                              'Contribuer',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Paiement sécurisé sur la page du fournisseur — la '
                      'confirmation revient automatiquement au Mouvement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
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

  static String _formatFcfa(int m) {
    final s = m.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      b.write(s[i]);
      final restant = s.length - 1 - i;
      if (restant > 0 && restant % 3 == 0) b.write(' ');
    }
    return b.toString();
  }

  Widget _champEmail() => TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: AppColors.texte, fontSize: 14),
        decoration: _decoration('Email (reçu de confirmation) *').copyWith(
          prefixIcon: const Icon(Icons.alternate_email, color: AppColors.or, size: 19),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Email requis';
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v.trim())) {
            return 'Adresse email invalide';
          }
          return null;
        },
      );

  Widget _champ(TextEditingController c, String libelle, IconData icone, String indice) =>
      TextFormField(
        controller: c,
        style: const TextStyle(color: AppColors.texte, fontSize: 14),
        decoration: _decoration(libelle).copyWith(
          prefixIcon: Icon(icone, color: AppColors.or, size: 19),
          hintText: indice,
          hintStyle: const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
        ),
      );

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
}

class _CartePasserelle extends StatelessWidget {
  final String id;
  final String titre;
  final String sousTitre;
  final IconData icone;
  final bool actif;
  final VoidCallback onSelect;

  const _CartePasserelle({
    required this.id,
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.actif,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.pourpre,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: actif ? AppColors.or : AppColors.pourpreClair,
            width: actif ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icone, color: actif ? AppColors.or : AppColors.texteSecondaire, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      color: actif ? AppColors.or : AppColors.texte,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sousTitre,
                    style: const TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(
              actif ? Icons.radio_button_checked : Icons.radio_button_off,
              color: actif ? AppColors.or : AppColors.texteEteint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

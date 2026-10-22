/// ⭐ V2.10 — INSCRIPTION : reproduction fidèle du flux web `/register`
/// (V3.11 / V4.08) pour la parité mobile ↔ web.
///
/// Champs identiques au web : nom complet*, email*, mot de passe* (8+),
/// pseudonyme (nom sur la carte des dispersés), pays* (recherche +
/// suggestions), ville, langue (FR/EN/ES/PT/HE).
///
/// POST `/api/auth/register` → le SERVEUR fait tout le reste :
/// · compte MEMBRE auto-validé (isVerified: true) ;
/// · inscription automatique aux canaux publics ;
/// · annonce « Baruch haba ! » dans le canal d'accueil ;
/// · placement sur la carte des dispersés (pays → coordonnées).
///
/// Après succès : retour à l'écran de connexion, email pré-rempli.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';
import '../../data/pays.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pseudonymeCtrl = TextEditingController();
  final _paysCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();

  /// Pays sélectionné (null = recherche en cours, rien de retenu).
  Pays? _paysChoisi;
  String _langue = 'FR';
  bool _obscure = true;
  bool _envoi = false;
  String? _erreur;

  static const _langues = [
    ('FR', 'Français'),
    ('EN', 'English'),
    ('ES', 'Español'),
    ('PT', 'Português'),
    ('HE', 'עברית'),
  ];

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _pseudonymeCtrl.dispose();
    _paysCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  // ── Suggestions de pays (filtre live, comme le web : 6 max) ──
  List<Pays> get _suggestions {
    if (_paysChoisi != null) return const [];
    final q = _paysCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return kPays
        .where((p) =>
            p.nom.toLowerCase().contains(q) ||
            p.code.toLowerCase() == q)
        .take(6)
        .toList();
  }

  /// ⭐ Parité V3.24 web — auto-résolution du pays : si l'utilisateur
  /// tape le nom complet (ou le code) sans cliquer la suggestion, on
  /// résout quand même (match exact, sinon préfixe unique) — évite le
  /// « bouton Créer ne fait rien » sans message.
  Pays? _resoudrePays(String texte) {
    final q = texte.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final p in kPays) {
      if (p.nom.toLowerCase() == q || p.code.toLowerCase() == q) return p;
    }
    Pays? prefixeUnique;
    var nbPrefixes = 0;
    for (final p in kPays) {
      if (p.nom.toLowerCase().startsWith(q)) {
        nbPrefixes++;
        prefixeUnique = p;
      }
    }
    return nbPrefixes == 1 ? prefixeUnique : null;
  }

  Future<void> _creerCompte() async {
    // Auto-résolution du pays avant validation (cf. V3.24 web).
    if (_paysChoisi == null) {
      final resolu = _resoudrePays(_paysCtrl.text);
      if (resolu != null) {
        setState(() {
          _paysChoisi = resolu;
          _paysCtrl.text = resolu.nom;
        });
      }
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });

    final emailFinal = _emailCtrl.text.trim();

    try {
      await AuthRepository().register(
        name: _nomCtrl.text.trim(),
        email: emailFinal,
        password: _passwordCtrl.text,
        pseudonyme: _pseudonymeCtrl.text.trim(),
        pays: _paysChoisi!.code,
        ville: _villeCtrl.text.trim(),
        langue: _langue,
      );
      if (!mounted) return;

      // ⭐ Succès (le serveur a déjà joint les canaux publics, posté
      // « Baruch haba ! » et placé le membre sur la carte des dispersés).
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.pourpre,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.orFonce),
          ),
          title: const Text(
            'Compte créé !',
            style: TextStyle(
              color: AppColors.or,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Baruch haba ! Bienvenue dans la communauté.\n\n'
            'Vous apparaissez désormais sur la carte des dispersés. '
            'Connectez-vous pour rejoindre la messagerie.',
            style: TextStyle(color: AppColors.texte, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Se connecter',
                style: TextStyle(
                  color: AppColors.or,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;

      // Retour à la connexion, email pré-rempli (le mot de passe, lui,
      // n'est jamais pré-rempli).
      context.pushReplacement('/login', extra: emailFinal);
    } on ApiException catch (e) {
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    } catch (_) {
      setState(() {
        _envoi = false;
        _erreur = 'Inscription impossible — vérifiez votre connexion et réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.orPastel),
          onPressed: _envoi
              ? null
              : () => context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: const Text(
          'Rejoindre la communauté',
          style: TextStyle(
            color: AppColors.or,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Identité (même en-tête que la connexion) ──
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
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
                        width: 86,
                        excludeFromSemantics: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Inscription',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.or,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Vous rejoignez immédiatement la communauté des dispersés',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Nom complet ──
                  TextFormField(
                    controller: _nomCtrl,
                    enabled: !_envoi,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.person_outline, color: AppColors.orPastel),
                      hintText: 'Nom complet *',
                    ),
                    style: const TextStyle(color: AppColors.texte),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Entrez votre nom complet'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Email ──
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: !_envoi,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.mail_outline, color: AppColors.orPastel),
                      hintText: 'Email *',
                    ),
                    style: const TextStyle(color: AppColors.texte),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isEmpty) return 'Entrez votre email';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email)) {
                        return 'Adresse email invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Mot de passe ──
                  TextFormField(
                    controller: _passwordCtrl,
                    enabled: !_envoi,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: AppColors.orPastel),
                      hintText: 'Mot de passe * (8 caractères minimum)',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.texteSecondaire,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.texte),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Le mot de passe doit faire au moins 8 caractères'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Pseudonyme (nom sur la carte des dispersés) ──
                  TextFormField(
                    controller: _pseudonymeCtrl,
                    enabled: !_envoi,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.map_outlined,
                          color: AppColors.orPastel),
                      hintText: 'Pseudonyme — nom sur la carte des dispersés',
                    ),
                    style: const TextStyle(color: AppColors.texte),
                  ),
                  const SizedBox(height: 14),

                  // ── Pays (recherche + suggestions, comme le web) ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _paysCtrl,
                        enabled: !_envoi,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.text,
                        onChanged: (_) => setState(() {
                          // Toute frappe relance la recherche (comme le
                          // web) — le rebuild recalcule _suggestions.
                          _paysChoisi = null;
                        }),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.public,
                              color: AppColors.orPastel),
                          hintText: 'Pays * — recherchez puis sélectionnez',
                          suffixIcon: _paysChoisi != null
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.succes, size: 20)
                              : (suggestions.isNotEmpty
                                  ? const Icon(Icons.search,
                                      color: AppColors.texteSecondaire,
                                      size: 20)
                                  : null),
                        ),
                        style: const TextStyle(color: AppColors.texte),
                        validator: (v) => _paysChoisi == null
                            ? 'Sélectionnez votre pays dans les suggestions '
                              '(tapez puis touchez le pays)'
                            : null,
                      ),
                      if (suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: AppColors.pourpre,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.orFonce.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (final p in suggestions)
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _envoi
                                      ? null
                                      : () => setState(() {
                                            _paysChoisi = p;
                                            _paysCtrl.text = p.nom;
                                          }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.nom,
                                            style: const TextStyle(
                                              color: AppColors.texte,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          p.code,
                                          style: const TextStyle(
                                            color: AppColors.texteSecondaire,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (suggestions.length == 6)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(
                                    'Continuez à taper pour affiner…',
                                    style: TextStyle(
                                      color: AppColors.texteEteint,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Ville ──
                  TextFormField(
                    controller: _villeCtrl,
                    enabled: !_envoi,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.addressLevel2],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_city_outlined,
                          color: AppColors.orPastel),
                      hintText: 'Ville',
                    ),
                    style: const TextStyle(color: AppColors.texte),
                  ),
                  const SizedBox(height: 14),

                  // ── Langue ──
                  DropdownButtonFormField<String>(
                    value: _langue,
                    items: [
                      for (final (code, label) in _langues)
                        DropdownMenuItem(
                          value: code,
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.texte,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                    onChanged: _envoi
                        ? null
                        : (v) => setState(() => _langue = v ?? 'FR'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.translate_outlined,
                          color: AppColors.orPastel),
                      hintText: 'Langue',
                    ),
                    dropdownColor: AppColors.pourpre,
                    style: const TextStyle(color: AppColors.texte, fontSize: 14),
                  ),
                  const SizedBox(height: 22),

                  // ── Erreur (bloc rouge, comme la connexion) ──
                  if (_erreur != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _erreur!,
                              style: const TextStyle(
                                color: AppColors.texte,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ── Bouton ──
                  ElevatedButton(
                    onPressed: _envoi ? null : _creerCompte,
                    child: _envoi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.nuit,
                            ),
                          )
                        : const Text('Créer mon compte'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'En créant votre compte, vous rejoignez immédiatement la '
                    'communauté et apparaissez sur la carte des dispersés.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.texteEteint,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

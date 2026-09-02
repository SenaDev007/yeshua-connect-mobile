/// Connexion membre — pseudonyme OU email + mot de passe.
/// Comptes validés par un administrateur (isVerified côté serveur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pseudoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _envoi = false;

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final ok = await ref
        .read(authProvider.notifier)
        .login(_pseudoCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (ok) {
      context.go('/app');
    }
    // Sinon : le message d'erreur est déjà dans l'état authProvider.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Identité ──
                  const Icon(Icons.church, color: AppColors.or, size: 72),
                  const SizedBox(height: 20),
                  const Text(
                    'Yeshua Connect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.or,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mouvement Christ Libère',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.texteSecondaire, fontSize: 14),
                  ),
                  const SizedBox(height: 48),

                  // ── Champs ──
                  TextFormField(
                    controller: _pseudoCtrl,
                    enabled: !_envoi,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.orPastel),
                      hintText: 'Pseudonyme ou email',
                    ),
                    style: const TextStyle(color: AppColors.texte),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Entrez votre pseudonyme ou email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    enabled: !_envoi,
                    obscureText: _obscure,
                    onFieldSubmitted: (_) => _seConnecter(),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.orPastel),
                      hintText: 'Mot de passe',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.texteSecondaire,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.texte),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Entrez votre mot de passe' : null,
                  ),

                  // ── Erreur ──
                  if (auth.error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: const TextStyle(color: AppColors.texte, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Bouton ──
                  ElevatedButton(
                    onPressed: _envoi ? null : _seConnecter,
                    child: _envoi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.nuit,
                            ),
                          )
                        : const Text('Se connecter'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '« Là où l\'Esprit du Seigneur est, il y a liberté » — 2 Corinthiens 3:17',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.texteEteint,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
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

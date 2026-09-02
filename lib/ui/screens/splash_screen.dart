/// Écran d'attente pendant la restauration de session JWT.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoute l'état d'auth : dès qu'il tranche, route vers login ou app.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/app');
      } else if (next.status == AuthStatus.unauthenticated) {
        context.go('/login');
      }
    });

    return const Scaffold(
      backgroundColor: AppColors.nuit,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Croix dorée — identité du mouvement
            Icon(Icons.church, color: AppColors.or, size: 64),
            SizedBox(height: 24),
            Text(
              'Yeshua Connect',
              style: TextStyle(
                color: AppColors.or,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mouvement Christ Libère',
              style: TextStyle(color: AppColors.texteSecondaire, fontSize: 13),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: AppColors.or,
                strokeWidth: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Point d'entrée de Yeshua Connect V1.1 — Mouvement Christ Libère.
///
/// V1.1 : correctif du NOM DE L'APPELANT sur l'écran d'appel entrant
/// (un privé titre l'appelant via `initiatorName`, jamais le nom du
/// canal qui est celui du destinataire).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/api/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cookie jar persistant AVANT la première requête (session NextAuth).
  await ApiClient.instance.ensureInitialized();

  runApp(const ProviderScope(child: YeshuaConnectApp()));
}

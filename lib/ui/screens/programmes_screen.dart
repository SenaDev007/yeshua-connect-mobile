/// ⭐ V1.5 — Écran « Messages programmés » (parité web).
///
/// Liste de MES messages en attente (status PENDING) : envoyés
/// automatiquement à l'heure prévue par le cron serveur
/// `/api/cron/dispatch-scheduled` — le même qui servait le web. La
/// création se fait depuis le composer d'un canal (bouton ➕).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/announcement_model.dart';
import '../../data/repositories/messages_repository.dart';
import '../../state/conversations_controller.dart';

class ProgrammesScreen extends ConsumerStatefulWidget {
  const ProgrammesScreen({super.key});

  @override
  ConsumerState<ProgrammesScreen> createState() => _ProgrammesScreenState();
}

class _ProgrammesScreenState extends ConsumerState<ProgrammesScreen> {
  final MessagesRepository _repo = MessagesRepository();

  List<MessageProgrammeModel> _programmes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final programmes = await _repo.mesProgrammes();
      if (!mounted) return;
      setState(() {
        _programmes = programmes;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString();
      });
    }
  }

  /// Nom du canal depuis l'état des conversations (best effort).
  String _nomCanal(String channelId) {
    final convs = ref.read(conversationsProvider).conversations;
    for (final c in convs) {
      if (c.id == channelId) return c.displayName;
    }
    return 'Canal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(title: const Text('Messages programmés')),
      body: RefreshIndicator(
        color: AppColors.or,
        backgroundColor: AppColors.pourpre,
        onRefresh: _charger,
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: AppColors.or))
            : _erreur != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.cloud_off,
                        size: 52, color: AppColors.danger),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _erreur!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.texteSecondaire, fontSize: 13.5),
                      ),
                    ),
                  ])
                : _programmes.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 110),
                        Icon(Icons.schedule_send_outlined,
                            size: 56, color: AppColors.texteEteint),
                        SizedBox(height: 14),
                        Text(
                          'Aucun message programmé',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.texteSecondaire,
                              fontSize: 15),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Depuis un canal, touchez ➕ puis « Programmer un '
                            'message » : il partira automatiquement à '
                            'l\'heure choisie.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.texteEteint,
                                fontSize: 12.5,
                                height: 1.5),
                          ),
                        ),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(14),
                        itemCount: _programmes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _carte(_programmes[i]),
                      ),
      ),
    );
  }

  Widget _carte(MessageProgrammeModel m) {
    final d = m.scheduledAt;
    final enRetard = m.enAttente && d.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: enRetard
                ? AppColors.or.withValues(alpha: 0.5)
                : AppColors.or.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enRetard ? Icons.hourglass_top : Icons.schedule,
                size: 14,
                color: enRetard ? AppColors.or : AppColors.texteEteint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${Formatters.jour(d)} à ${Formatters.heure(d)}',
                  style: const TextStyle(
                      color: AppColors.orPastel,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: m.enAttente
                      ? AppColors.or.withValues(alpha: 0.16)
                      : AppColors.succes.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  m.enAttente ? 'EN ATTENTE' : m.status,
                  style: TextStyle(
                      color:
                          m.enAttente ? AppColors.or : AppColors.succes,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.texte, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'vers ${_nomCanal(m.channelId)}',
            style: const TextStyle(
                color: AppColors.texteEteint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

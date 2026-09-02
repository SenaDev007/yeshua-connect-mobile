/// Bulle d'un message : moi (pourpre clair, à droite) / autre (nuit
/// éclairci, à gauche, avec avatar + prénom en groupe).
///
/// Les CALL_LOG s'affichent en pastille centrée — même rendu que le web.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/message_model.dart';
import 'avatar_widget.dart';
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSender; // afficher avatar + nom (groupe, non-consécutif)

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isCallLog) {
      return _pastilleAppel();
    }

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    final bulle = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? AppColors.bulleMoi : AppColors.bulleAutre,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rappel de réponse
          if (message.hasReply) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.nuit.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.replyToSenderName ?? '',
                    style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((message.replyToContent ?? '').isNotEmpty)
                    Text(
                      Formatters.apercu(message.replyToContent, max: 50),
                      style: const TextStyle(
                        color: AppColors.texteSecondaire,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          // Verset biblique : référence dorée + texte italique
          if (message.isVerse) ...[
            Text(
              message.verseRef ?? '',
              style: const TextStyle(
                color: AppColors.or,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            message.content,
            style: TextStyle(
              color: AppColors.texte,
              fontSize: 14.5,
              height: 1.4,
              fontStyle: message.isVerse ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (message.isPinned) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 11, color: AppColors.or.withOpacity(0.8)),
                const SizedBox(width: 3),
                Text(
                  'Épinglé',
                  style: TextStyle(
                    color: AppColors.or.withOpacity(0.8),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.editedAt != null) ...[
                const Text(
                  'modifié ',
                  style: TextStyle(color: AppColors.texteEteint, fontSize: 10),
                ),
              ],
              Text(
                Formatters.heure(message.createdAt),
                style: const TextStyle(color: AppColors.texteEteint, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showSender)
              AvatarWidget(
                photoUrl: message.senderAvatarUrl,
                name: message.senderName,
                size: 30,
              )
            else
              const SizedBox(width: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && !isMe) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: AppColors.orPastel,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                bulle,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Journal d'appel (CALL_LOG) : « Appel audio manqué » centré, discret.
  Widget _pastilleAppel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pourpre,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_missed, size: 13, color: AppColors.texteSecondaire),
                const SizedBox(width: 6),
                Text(
                  message.content,
                  style: const TextStyle(
                    color: AppColors.texteSecondaire,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

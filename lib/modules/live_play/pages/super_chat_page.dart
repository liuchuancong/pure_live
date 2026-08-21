import 'package:flutter/material.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/modules/live_play/widgets/layout/super_chat_card.dart';

class SuperChatPage extends StatelessWidget {
  final List<LiveSuperChatMessage> messages;

  const SuperChatPage({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final uniqueMessages = <String, LiveSuperChatMessage>{};

    for (final message in messages) {
      final key = '${message.userName}|${message.message}|${message.price}';

      uniqueMessages.putIfAbsent(key, () => message);
    }

    final list = uniqueMessages.values.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final message = list[index];

        return Padding(padding: const EdgeInsets.only(bottom: 8), child: SuperChatCard(message));
      },
    );
  }
}

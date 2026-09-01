import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_physics.dart';
import 'package:pure_live/modules/live_play/widgets/layout/super_chat_card.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class SuperChatPage extends StatelessWidget {
  const SuperChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LivePlayController>();

    return Obx(() {
      final messages = controller.superChats;

      if (messages.isEmpty) {
        return const SizedBox.shrink();
      }

      final uniqueMessages = <String, LiveSuperChatMessage>{};
      for (final message in messages) {
        final key = message.messageId.isNotEmpty
            ? message.messageId
            : '${message.userName}|${message.message}|${message.price}|${message.startTime.microsecondsSinceEpoch}';
        uniqueMessages.putIfAbsent(key, () => message);
      }

      final list = uniqueMessages.values.toList();

      return ListView.builder(
        primary: false,
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final message = list[index];
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: SuperChatCard(message));
        },
      );
    });
  }
}

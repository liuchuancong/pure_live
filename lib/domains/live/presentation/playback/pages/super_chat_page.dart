import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/layout/super_chat_card.dart';

class SuperChatPage extends StatelessWidget {
  final List<LiveSuperChatMessage> messages;

  const SuperChatPage({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      final theme = Theme.of(context);
      return ListView(
        key: const ValueKey('super-chat-empty-state'),
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          Icon(Remix.chat_smile_3_line, size: 42, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            i18n('super_chat_empty_title'),
            textAlign: TextAlign.center,
            style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            i18n('super_chat_empty_subtitle'),
            textAlign: TextAlign.center,
            style: AppTextStyles.t13.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final list = <LiveSuperChatMessage>{...messages}.toList(growable: false);

    return ListView.builder(
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final message = list[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SuperChatCard(message, key: ValueKey<LiveSuperChatMessage>(message)),
        );
      },
    );
  }
}

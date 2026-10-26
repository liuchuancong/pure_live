import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/shield/shield_repository.dart' show shieldRulesProvider;
import 'package:pure_live/l10n/translations.dart';

/// The actions one chat line offers: copy its words, block the sender, or
/// block a keyword (the reference's danmaku message panel).
enum RoomMessageAction { copy, blockUser, blockKeyword }

/// Opens the actions of a tapped flying danmaku over the picture. Local
/// echoes offer copying only: blocking their own viewer or words would cut
/// the viewer's own lines without ever stopping the platform's.
Future<void> showRoomMessageActions(
  BuildContext context,
  WidgetRef ref, {
  required String text,
  required String userName,
  required bool isLocal,
}) async {
  final name = userName.trim();
  final action = await showDsPanel<RoomMessageAction>(
    context: context,
    builder: (panelContext) {
      final t = panelContext.t;
      final theme = DsTheme.of(panelContext);
      return DsPanel(
        title: Text(t.room.messageActions),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s4,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.s8),
              child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.typography.body),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.copy),
              title: Text(t.room.copy),
              onPressed: () => Navigator.of(panelContext).pop(RoomMessageAction.copy),
            ),
            if (!isLocal && name.isNotEmpty)
              DsListRow(
                leading: const DsIcon(DsIcons.ban),
                title: Text(t.room.blockUser),
                onPressed: () => Navigator.of(panelContext).pop(RoomMessageAction.blockUser),
              ),
            if (!isLocal)
              DsListRow(
                leading: const DsIcon(DsIcons.shield),
                title: Text(t.room.blockKeyword),
                onPressed: () => Navigator.of(panelContext).pop(RoomMessageAction.blockKeyword),
              ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case RoomMessageAction.copy:
      await copyRoomMessageText(context, text);
    case RoomMessageAction.blockUser:
      await blockRoomMessageSender(context, ref, name);
    case RoomMessageAction.blockKeyword:
      await blockRoomMessageKeyword(context, ref, text);
  }
}

/// Copies a line's words and says so.
Future<void> copyRoomMessageText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showDsToast(context: context, title: context.t.room.copied);
}

/// Adds a sender name to the shield's user list.
Future<void> blockRoomMessageSender(BuildContext context, WidgetRef ref, String name) async {
  final added = await ref.read(shieldRulesProvider.notifier).addUser(name);
  if (!context.mounted) return;
  showDsToast(context: context, title: added ? context.t.room.userBlocked : context.t.shield.duplicateEntry);
}

/// Asks for the word to cut out of a line, offering the whole line first,
/// then adds it to the shield's keyword list.
Future<void> blockRoomMessageKeyword(BuildContext context, WidgetRef ref, String text) async {
  final t = context.t;
  final key = GlobalKey<_KeywordEditorState>();
  final picked = await showDsDialog<String>(
    context: context,
    builder: (dialogContext) => DsDialog(
      title: Text(t.room.blockKeyword),
      icon: const DsIcon(DsIcons.shield),
      description: _KeywordEditor(key: key, initial: text, onSubmit: (word) => Navigator.of(dialogContext).pop(word)),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          variant: DsButtonVariant.danger,
          onPressed: () {
            final word = key.currentState?.value ?? '';
            if (word.isNotEmpty) Navigator.of(dialogContext).pop(word);
          },
          child: Text(t.room.block),
        ),
      ],
    ),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  final added = await ref.read(shieldRulesProvider.notifier).addKeyword(picked);
  if (!context.mounted) return;
  showDsToast(context: context, title: added ? t.room.keywordBlocked : t.shield.duplicateEntry);
}

/// The keyword field of the block dialog: the whole line is offered, cut
/// down to the word that should be dropped; Enter confirms.
final class _KeywordEditor extends StatefulWidget {
  const _KeywordEditor({required this.initial, required this.onSubmit, super.key});

  final String initial;
  final ValueChanged<String> onSubmit;

  @override
  State<_KeywordEditor> createState() => _KeywordEditorState();
}

final class _KeywordEditorState extends State<_KeywordEditor> {
  late final TextEditingController _field = TextEditingController(text: widget.initial);

  String get value => _field.text.trim();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DsTextField(
    controller: _field,
    autofocus: true,
    clearable: true,
    maxLength: 40,
    placeholder: context.t.room.blockKeywordHint,
    onSubmitted: (word) {
      final value = word.trim();
      if (value.isNotEmpty) widget.onSubmit(value);
    },
  );
}

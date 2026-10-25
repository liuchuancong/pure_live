import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/settings/danmaku_style_providers.dart';
import 'package:pure_live/features/settings/playback_settings_providers.dart';
import 'package:pure_live/features/shield/shield_pane.dart' show ShieldPane;
import 'package:pure_live/features/shield/shield_repository.dart' show shieldRulesProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;

/// The room's chat column: four tabs, as the reference's `ChatPanel` has —
/// the danmaku list with its composer, the super chats where the platform
/// keeps a board, the flying layer's own settings, and the shield's lists.
/// The tab is the panel's own state; a narrow column scrolls its bar rather
/// than cutting a label.
enum _ChatTab { danmaku, superChats, settings, shield }

/// The chat column under (or beside) the picture.
final class RoomChatPanel extends ConsumerStatefulWidget {
  /// The chat column.
  const RoomChatPanel({super.key});

  @override
  ConsumerState<RoomChatPanel> createState() => _RoomChatPanelState();
}

final class _RoomChatPanelState extends ConsumerState<RoomChatPanel> {
  _ChatTab _tab = _ChatTab.danmaku;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final room = ref.watch(roomProvider).room;
    final site = room == null ? null : ref.watch(sitesProvider).getById(room.ref.platform);
    final superChats = site?.capability<LiveSuperChatFeed>() != null;
    // A room change can take the board away; the tab falls back to the
    // list rather than to an empty super-chat page.
    final tab = _tab == _ChatTab.superChats && !superChats ? _ChatTab.danmaku : _tab;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsTabs<_ChatTab>(
            value: tab,
            onChanged: (value) => setState(() => _tab = value),
            semanticLabel: t.room.chatTitle,
            tabs: [
              DsTab(value: _ChatTab.danmaku, label: Text(t.room.danmakuList)),
              if (superChats) DsTab(value: _ChatTab.superChats, label: Text(t.room.superChats)),
              DsTab(value: _ChatTab.settings, label: Text(t.room.danmakuSettings)),
              DsTab(value: _ChatTab.shield, label: Text(t.room.blockList)),
            ],
          ),
          DsLine(color: colors.border),
          Expanded(
            child: switch (tab) {
              _ChatTab.danmaku => const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Expanded(child: _ChatFeed()), _ChatComposer()],
              ),
              _ChatTab.superChats => _SuperChatTab(room: room!),
              _ChatTab.settings => const _RoomDanmakuSettings(),
              _ChatTab.shield => const _ShieldTab(),
            },
          ),
        ],
      ),
    );
  }
}

/// The danmaku list: the pipeline's messages, newest at the bottom, the
/// sender's name before the text in the sender's color. A long press (or a
/// right click) opens the message's actions.
final class _ChatFeed extends ConsumerWidget {
  const _ChatFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final chat = ref.watch(roomChatProvider);
    if (chat.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.messageCircle), title: Text(t.room.noChat)),
      );
    }
    // Reversed: item 0 sits at the bottom, so new messages stay in view
    // without a scroll command, and scrolling up leaves the list where the
    // viewer put it.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
      itemCount: chat.length,
      itemBuilder: (context, index) => _ChatLine(message: chat[chat.length - 1 - index]),
    );
  }
}

/// The chat composer: the field and the send button, only when the room's
/// chat accepts a posted message; a failure toasts, a success clears the
/// field.
final class _ChatComposer extends ConsumerStatefulWidget {
  const _ChatComposer();

  @override
  ConsumerState<_ChatComposer> createState() => _ChatComposerState();
}

final class _ChatComposerState extends ConsumerState<_ChatComposer> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canSend = ref.watch(roomProvider.notifier).canSendDanmaku;
    if (!canSend) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsTextField(
              controller: _field,
              clearable: true,
              placeholder: t.room.sendHint,
              onSubmitted: (word) => unawaited(_send(word)),
            ),
          ),
          DsButton(onPressed: () => unawaited(_send(_field.text)), child: Text(t.room.send)),
        ],
      ),
    );
  }

  Future<void> _send(String word) async {
    if (word.trim().isEmpty) return;
    final failure = await ref.read(roomProvider.notifier).sendDanmaku(word);
    if (!mounted) return;
    if (failure == null) {
      _field.clear();
    } else {
      showDsToast(context: context, title: context.t.room.sendFailed);
    }
  }
}

/// One chat line: the sender and the text, the platform's own colour when
/// it gave one. Its context menu copies the line, blocks the sender, or
/// blocks a keyword to cut out of the line.
final class _ChatLine extends ConsumerWidget {
  const _ChatLine({required this.message});

  final LiveMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sender = message.sender;
    final nameStyle = theme.typography.caption.copyWith(
      color: message.color == null
          ? colors.textMuted
          : Color.fromARGB(255, message.color!.r, message.color!.g, message.color!.b),
    );
    final senderName = sender?.userName.trim() ?? '';
    return DsContextMenuRegion(
      semanticLabel: t.room.messageActions,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(t.room.copy),
          onPressed: () => unawaited(_copy(context, message.text)),
        ),
        if (!message.isLocal && senderName.isNotEmpty)
          DsMenuItem(
            leading: const DsIcon(DsIcons.ban),
            label: Text(t.room.blockUser),
            onPressed: () => unawaited(_blockUser(context, ref, senderName)),
          ),
        if (!message.isLocal)
          DsMenuItem(
            leading: const DsIcon(DsIcons.shield),
            label: Text(t.room.blockKeyword),
            onPressed: () => unawaited(_blockKeyword(context, ref, message)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.s3),
        child: Text.rich(
          TextSpan(
            children: [
              if (senderName.isEmpty)
                TextSpan(text: '${t.room.system}: ', style: nameStyle)
              else
                TextSpan(text: '$senderName: ', style: nameStyle),
              TextSpan(
                text: message.text,
                style: theme.typography.caption.copyWith(color: colors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showDsToast(context: context, title: context.t.room.copied);
  }

  Future<void> _blockUser(BuildContext context, WidgetRef ref, String name) async {
    final added = await ref.read(shieldRulesProvider.notifier).addUser(name);
    if (!context.mounted) return;
    showDsToast(context: context, title: added ? context.t.room.userBlocked : context.t.shield.duplicateEntry);
  }

  Future<void> _blockKeyword(BuildContext context, WidgetRef ref, LiveMessage message) async {
    final t = context.t;
    final key = GlobalKey<_KeywordEditorState>();
    final picked = await showDsDialog<String>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.room.blockKeyword),
        icon: const DsIcon(DsIcons.shield),
        description: _KeywordEditor(
          key: key,
          initial: message.text,
          onSubmit: (word) => Navigator.of(dialogContext).pop(word),
        ),
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
    if (picked == null || picked.isEmpty) return;
    final added = await ref.read(shieldRulesProvider.notifier).addKeyword(picked);
    if (!context.mounted) return;
    showDsToast(context: context, title: added ? t.room.keywordBlocked : t.shield.duplicateEntry);
  }
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

/// The flying danmaku's own settings, right beside the list: whether it
/// draws, then size, speed, the share of the picture it may cross, opacity,
/// the outline and the way back to the defaults.
final class _RoomDanmakuSettings extends ConsumerWidget {
  const _RoomDanmakuSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s20),
      children: [
        DsSwitch(
          value: settings.danmakuVisible,
          onChanged: (value) =>
              unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: value)),
          label: Text(t.room.danmakuOn),
          description: Text(t.room.danmakuSettingsDesc),
        ),
        const SizedBox(height: DsSpace.s12),
        _StyleSlider(
          icon: DsIcons.type,
          label: t.settings.styleFontSize,
          shown: '${style.fontSize.round()}',
          value: style.fontSize,
          min: DanmakuStyleRange.fontSizeMin,
          max: DanmakuStyleRange.fontSizeMax,
          onChanged: (value) => unawaited(controller.setFontSize(value)),
        ),
        _StyleSlider(
          icon: DsIcons.wind,
          label: t.settings.styleSpeed,
          shown: '${style.baseSpeed.round()}',
          value: style.baseSpeed,
          min: DanmakuStyleRange.speedMin,
          max: DanmakuStyleRange.speedMax,
          onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
        ),
        _StyleSlider(
          icon: DsIcons.moveVertical,
          label: t.settings.styleArea,
          shown: '${(style.area * 100).round()}%',
          value: style.area,
          min: DanmakuStyleRange.areaMin,
          max: 1,
          onChanged: (value) => unawaited(controller.setArea(value)),
        ),
        _StyleSlider(
          icon: DsIcons.circle,
          label: t.settings.styleOpacity,
          shown: '${(style.opacity * 100).round()}%',
          value: style.opacity,
          min: DanmakuStyleRange.opacityMin,
          max: 1,
          onChanged: (value) => unawaited(controller.setOpacity(value)),
        ),
        const SizedBox(height: DsSpace.s8),
        DsSwitch(
          value: style.showStroke,
          onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
          label: Text(t.settings.styleStroke),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCw),
          title: Text(t.settings.styleReset),
          onPressed: () => unawaited(controller.reset()),
        ),
      ],
    );
  }
}

/// One labelled slider of the in-room danmaku settings.
final class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.icon,
    required this.label,
    required this.shown,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final DsIconData icon;
  final String label;
  final String shown;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          Row(
            spacing: DsSpace.s6,
            children: [
              DsIcon(icon, size: theme.sizes.iconSm, color: colors.textMuted),
              Expanded(
                child: Text(label, style: theme.typography.body.copyWith(color: colors.text)),
              ),
              Text(shown, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
            ],
          ),
          DsSlider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}

/// The super chat board: the platform's own list, read when the tab opens;
/// a failure names the reason and offers a retry.
final class _SuperChatTab extends ConsumerStatefulWidget {
  const _SuperChatTab({required this.room});

  final LiveRoom room;

  @override
  ConsumerState<_SuperChatTab> createState() => _SuperChatTabState();
}

typedef _SuperChats = ({List<LiveSuperChatMessage> messages, String? error});

final class _SuperChatTabState extends ConsumerState<_SuperChatTab> {
  late Future<_SuperChats> _future = _load();

  Future<_SuperChats> _load() async {
    final capability = ref.read(sitesProvider).getById(widget.room.ref.platform)?.capability<LiveSuperChatFeed>();
    if (capability == null) return (messages: const <LiveSuperChatMessage>[], error: null);
    final answer = await capability.getSuperChatMessages(room: widget.room);
    final result = answer.fold(
      (error) => (messages: const <LiveSuperChatMessage>[], error: error.message),
      (messages) => (messages: messages, error: null),
    );
    return result;
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return FutureBuilder<_SuperChats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: DsSpinner());
        }
        final result = snapshot.data;
        if (result == null) {
          return DsEmptyState(
            icon: const DsIcon(DsIcons.badgeDollarSign),
            title: Text(t.room.superChatFailed),
            actions: [DsButton(onPressed: _retry, child: Text(t.common.retry))],
          );
        }
        if (result.error != null) {
          return DsEmptyState(
            icon: const DsIcon(DsIcons.badgeDollarSign),
            title: Text(t.room.superChatFailed),
            description: Text(result.error!),
            actions: [DsButton(onPressed: _retry, child: Text(t.common.retry))],
          );
        }
        if (result.messages.isEmpty) {
          return DsEmptyState(
            icon: const DsIcon(DsIcons.badgeDollarSign),
            title: Text(t.room.superChatEmpty),
            actions: [DsButton(variant: DsButtonVariant.secondary, onPressed: _retry, child: Text(t.common.retry))],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(DsSpace.s16),
          itemCount: result.messages.length,
          separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s8),
          itemBuilder: (context, index) => _SuperChatCard(message: result.messages[index]),
        );
      },
    );
  }
}

/// One paid message: who paid, how much, what was said and when it shows.
final class _SuperChatCard extends StatelessWidget {
  const _SuperChatCard({required this.message});

  final LiveSuperChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final name = message.userName.trim();
    final face = message.faceUrl.trim();
    final price = message.price.displayText.trim().isNotEmpty
        ? message.price.displayText.trim()
        : [
            ?message.price.currency,
            if (message.price.amount case final amount?) '$amount',
          ].join();
    return Container(
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: DsBoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          DsAvatar(
            initials: name,
            image: face.isEmpty ? null : cachedImage(face),
            size: DsSize.sm,
            semanticLabel: name,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                      ),
                    ),
                    if (price.isNotEmpty)
                      DsBadge(dot: false, label: Text(price), status: DsStatus.warning),
                  ],
                ),
                Text(message.text, style: theme.typography.body.copyWith(color: colors.text)),
                if (_shownAt() case final shown?)
                  Text(
                    shown,
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The time the message stays on the board, in the viewer's clock.
  String? _shownAt() {
    final start = message.startTime?.toLocal();
    final end = message.endTime?.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    String clock(DateTime time) => '${two(time.hour)}:${two(time.minute)}';
    if (start == null && end == null) return null;
    if (start != null && end != null) return '${clock(start)} – ${clock(end)}';
    return start == null ? clock(end!) : clock(start);
  }
}

/// The shield's lists inside the room: the same pane the settings page
/// shows, so a rule added here is the one that page lists.
final class _ShieldTab extends StatelessWidget {
  const _ShieldTab();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    padding: EdgeInsets.all(DsSpace.s16),
    child: ShieldPane(),
  );
}

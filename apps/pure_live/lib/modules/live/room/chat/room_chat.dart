import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/account/account_pane.dart' show AccountQrExit, showAccountSignInAlternative;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/chat/chat_message_filter.dart' show isStandaloneBadgeEcho;
import 'package:pure_live/modules/live/room/chat/gift_text.dart';
import 'package:pure_live/modules/live/room/chat/membership_cards.dart' show isMembershipCard;
import 'package:pure_live/modules/live/room/chat/paid_banner.dart';
import 'package:pure_live/modules/live/room/chat/room_chat_memory.dart'
    show RoomChatListMemory, roomChatListMemoryProvider;
import 'package:pure_live/modules/live/room/chat/room_emotes.dart';
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart'
    show blockRoomMessageKeyword, blockRoomMessageSender, copyRoomMessageText, showRoomMessageActions;
import 'package:pure_live/modules/live/room/chat/room_record_tab.dart';
import 'package:pure_live/modules/live/room/chat/room_super_chats.dart' show roomSuperChatsProvider;
import 'package:pure_live/modules/live/room/chat/room_user_card.dart' show showChatUserCard;
import 'package:pure_live/modules/live/room/chat/user_level_badge.dart' show UserLevelBadge;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/shield/shield.dart';
import 'package:pure_live/shared/player/emoji_atlas_loader.dart' show emojiAtlasCodes;
import 'package:pure_live/shared/shared.dart';

part 'room_chat_composer.dart';
part 'room_chat_feed.dart';
part 'room_chat_line.dart';
part 'room_chat_tabs.dart';

/// The room's chat column: four tabs — the danmaku list with its composer, the
/// super chats where the platform keeps a board, this room's own recording
/// figures, and the shield's lists. The tab is the panel's own state; a narrow
/// column scrolls its bar rather than cutting a label.
enum _ChatTab { danmaku, superChats, recording, shield }

/// The emoticons this room's talk has actually used: the platforms hand
/// their tables over inside the messages, so the composer's panel reads
/// what the column has seen instead of fetching a table of its own. First
/// sight wins a code's place; the picture travels with it.
final chatSeenEmotesProvider = Provider<List<LiveEmote>>((ref) {
  final seen = <String, String>{};
  for (final message in ref.watch(roomChatProvider)) {
    for (final emote in message.emotes) {
      final code = emote.code.trim();
      if (code.isEmpty || emote.url.trim().isEmpty) continue;
      seen.putIfAbsent(code, () => emote.url.trim());
    }
  }
  return [for (final entry in seen.entries) LiveEmote.of(code: entry.key, url: entry.value)];
});

/// The chat column under (or beside) the picture.
final class RoomChatPanel extends ConsumerStatefulWidget {
  /// The chat column.
  ///
  /// [translucent] leaves the panel's fill to its host: the theatre draws the
  /// column as a glass card over the picture, and a second opaque surface
  /// underneath would hide the glass.
  ///
  /// [feedOnly] keeps the danmaku list alone, with the login word that concerns
  /// it: a phone held sideways gives the chat a narrow column beside the
  /// picture, where the tab bar and the composer would leave a line or two of
  /// talk (the reference's landscape room shows its list and nothing else).
  ///
  /// [trailing] rides at the tab row's end — the theatre column's close verb
  /// lives there instead of floating over the last tab.
  const RoomChatPanel({this.translucent = false, this.feedOnly = false, this.trailing, super.key});

  /// Whether the panel paints no fill of its own.
  final bool translucent;

  /// Whether the panel is the danmaku list alone — no tabs, no composer.
  final bool feedOnly;

  /// A verb drawn at the end of the tab row, outside the tabs themselves.
  final Widget? trailing;

  @override
  ConsumerState<RoomChatPanel> createState() => _RoomChatPanelState();
}

final class _RoomChatPanelState extends ConsumerState<RoomChatPanel> {
  _ChatTab _tab = _ChatTab.danmaku;

  /// The newest line the viewer had reached when they last left the chat tab.
  ///
  /// Measured by identity rather than by counting arrivals, because the feed is
  /// capped: once it is full, a burst pushes the oldest talk out and the length
  /// stops moving, so a length difference would report that nothing arrived.
  String? _lastReadId;

  /// What the chat tab holds that the viewer has not seen, worn as its badge.
  int _unread = 0;

  /// Arrivals while the viewer is on another tab. The panel counts them, not the
  /// list, which is disposed the moment another tab is picked — a count kept
  /// there would reset at exactly the moment it matters.
  void _chatArrived(List<LiveMessage>? previous, List<LiveMessage> next) {
    if (_tab == _ChatTab.danmaku) return;
    final mark = _lastReadId;
    // A line the platform gave no id cannot serve as a mark; fall back to the
    // rows there are, which is right until the feed fills up.
    final unseen = mark == null || mark.isEmpty
        ? (previous == null || next.length <= previous.length ? _unread : next.length)
        : _after(next, mark);
    if (unseen == _unread) return;
    setState(() => _unread = unseen);
  }

  /// Picks a tab, or arms one of the row-end verbs: leaving the danmaku tab
  /// marks what the viewer had read, arriving at it clears the badge.
  void _select(_ChatTab value) {
    setState(() => _openTab(value));
  }

  /// The tab bookkeeping of [_select] without the setState: an outside ask
  /// arrives *through* this panel's rebuild, so its fields move inside the
  /// build that reads them.
  void _openTab(_ChatTab value) {
    if (value == _ChatTab.danmaku) {
      // Coming to the tab is reading it: the badge counts what the
      // viewer left behind, not what they are looking at.
      _lastReadId = null;
      _unread = 0;
    } else if (_tab == _ChatTab.danmaku) {
      final chat = ref.read(roomChatProvider);
      _lastReadId = chat.isEmpty ? null : chat.last.messageId;
      _unread = 0;
    }
    _tab = value;
  }

  static int _after(List<LiveMessage> chat, String mark) {
    final index = chat.lastIndexWhere((line) => line.messageId == mark);
    return index < 0 ? chat.length : chat.length - index - 1;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    // The super chat tab stays for every room, as the reference's chat
    // panel does, because a membership or a subscription can arrive where
    // the platform keeps no board.
    ref.listen(roomChatProvider, _chatArrived);
    final fill = widget.translucent ? OnVideoColors.clear : colors.surface;
    if (widget.feedOnly) {
      // The danmaku tab's own list, not a second one: the narrow column reads
      // and behaves exactly as the tab does, its boundary and count included.
      return ColoredBox(
        color: fill,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChatNoticeBar(),
            Expanded(child: _ChatFeed()),
          ],
        ),
      );
    }
    final board = ref.watch(roomSuperChatsProvider);
    final tab = _tab;
    final tabs = DsTabs<_ChatTab>(
      value: tab,
      onChanged: _select,
      semanticLabel: t.room.chatTitle,
      tabs: [
        DsTab(value: _ChatTab.danmaku, label: Text(t.room.danmakuList), count: _unread == 0 ? null : _unread),
        DsTab(
          value: _ChatTab.superChats,
          label: Text(t.room.tabSuperChats),
          count: board.messages.isEmpty ? null : board.messages.length,
        ),
        DsTab(value: _ChatTab.recording, label: Text(t.room.tabRecording)),
        DsTab(value: _ChatTab.shield, label: Text(t.room.tabShield)),
      ],
    );
    return ColoredBox(
      color: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The host's verb (the theatre column's close) rides at the row's
          // end, outside the tabs, so it never covers the last one.
          if (widget.trailing == null)
            tabs
          else
            Row(
              children: [
                Expanded(child: tabs),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: DsSpace.s4),
                  child: widget.trailing,
                ),
              ],
            ),
          DsLine(color: colors.border),
          Expanded(
            child: switch (tab) {
              _ChatTab.danmaku => const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChatNoticeBar(),
                  Expanded(child: _ChatFeed()),
                  _ChatComposer(),
                ],
              ),
              _ChatTab.superChats => const _SuperChatTab(),
              _ChatTab.recording => const RoomRecordTab(),
              _ChatTab.shield => const _ShieldTab(),
            },
          ),
        ],
      ),
    );
  }
}

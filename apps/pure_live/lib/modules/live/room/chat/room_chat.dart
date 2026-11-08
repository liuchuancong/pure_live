import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account_pane.dart' show AccountQrExit, showAccountSignInAlternative;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/chat/gift_text.dart';
import 'package:pure_live/modules/live/room/chat/membership_cards.dart' show isMembershipCard;
import 'package:pure_live/modules/live/room/chat/paid_banner.dart';
import 'package:pure_live/modules/live/room/chat/room_chat_memory.dart'
    show RoomChatListMemory, roomChatListMemoryProvider;
import 'package:pure_live/modules/live/room/chat/room_emotes.dart';
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart'
    show blockRoomMessageKeyword, blockRoomMessageSender, copyRoomMessageText;
import 'package:pure_live/modules/live/room/chat/room_record_tab.dart';
import 'package:pure_live/modules/live/room/chat/room_super_chats.dart' show roomSuperChatsProvider;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/shield/shield.dart';
import 'package:pure_live/shared/shared.dart';

/// The room's chat column: five tabs — the danmaku list with its composer, the
/// super chats where the platform keeps a board, this room's own recording
/// figures, the flying layer's settings, and the shield's lists. The tab is the
/// panel's own state; a narrow column scrolls its bar rather than cutting a
/// label.
enum _ChatTab { danmaku, superChats, recording, settings, shield }

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
  const RoomChatPanel({this.translucent = false, this.feedOnly = false, super.key});

  /// Whether the panel paints no fill of its own.
  final bool translucent;

  /// Whether the panel is the danmaku list alone — no tabs, no composer.
  final bool feedOnly;

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
    final tab = _tab;
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
    return ColoredBox(
      color: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsTabs<_ChatTab>(
            value: tab,
            onChanged: (value) => setState(() {
              if (value == _ChatTab.danmaku) {
                // Coming to the tab is reading it: the badge counts what the
                // viewer left behind, not what they are looking at.
                _lastReadId = null;
                _unread = 0;
              } else if (tab == _ChatTab.danmaku) {
                final chat = ref.read(roomChatProvider);
                _lastReadId = chat.isEmpty ? null : chat.last.messageId;
                _unread = 0;
              }
              _tab = value;
            }),
            semanticLabel: t.room.chatTitle,
            tabs: [
              DsTab(value: _ChatTab.danmaku, label: Text(t.room.danmakuList), count: _unread == 0 ? null : _unread),
              DsTab(
                value: _ChatTab.superChats,
                label: Text(t.room.tabSuperChats),
                // The board's own size rather than a count of unread: a paid
                // message is shown for its own minutes, so the number answers
                // "how many are pinned here", which is what the tab then lists.
                count: board.messages.isEmpty ? null : board.messages.length,
              ),
              DsTab(value: _ChatTab.recording, label: Text(t.room.tabRecording)),
              DsTab(value: _ChatTab.settings, label: Text(t.room.tabSettings)),
              DsTab(value: _ChatTab.shield, label: Text(t.room.tabShield)),
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
              _ChatTab.settings => const _RoomDanmakuSettings(),
              _ChatTab.shield => const _ShieldTab(),
            },
          ),
        ],
      ),
    );
  }
}

/// The room's standing word about its own chat login, above the list it
/// concerns.
///
/// A toast is the wrong shape for this: the viewer is looking at the picture
/// when the room notices that every name arrives masked, and the fix is a
/// minute at the sign-in page, not a glance. The bar stays until the next
/// connection stops looking like a dead login, or until they say they have
/// seen it.
final class _ChatNoticeBar extends ConsumerWidget {
  const _ChatNoticeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(roomChatNoticeProvider);
    if (notice == null) return const SizedBox.shrink();
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s12, 0),
      child: DsAlert(
        status: DsStatus.warning,
        announce: true,
        title: Text(notice.text),
        action: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.xs,
              onPressed: () => unawaited(
                showAccountSignInAlternative(context, siteId: notice.siteId, exit: AccountQrExit.cookiePage),
              ),
              child: Text(t.account.cookieLogin),
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.xs,
              icon: const DsIcon(DsIcons.close, size: 14),
              semanticLabel: t.common.close,
              onPressed: () => ref.read(roomChatNoticeProvider.notifier).clear(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The danmaku list: the pipeline's messages, newest at the bottom, the
/// sender's name before the text in the sender's color. A long press (or a
/// right click) opens the message's actions.
/// The area a chat or board state is shown in: centred when it fits the column,
/// scrollable when it does not.
///
/// The chat column is short on a phone and in a narrow desktop window, while a
/// failure state is a title, the platform's own reason — an exception line that
/// can run long — and a button. Under a plain `Center` that stack overflowed by
/// 343 px and lost its retry button off the bottom of the panel; nothing here
/// may be dropped, so the area gives way to scrolling instead of clipping.
Widget _chatStateArea({required Widget child}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      const padding = DsSpace.s12;
      final minHeight = constraints.hasBoundedHeight ? constraints.maxHeight - padding * 2 : 0.0;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight > 0 ? minHeight : 0),
          child: Center(child: child),
        ),
      );
    },
  );
}

final class _ChatFeed extends ConsumerStatefulWidget {
  const _ChatFeed();

  @override
  ConsumerState<_ChatFeed> createState() => _ChatFeedState();
}

final class _ChatFeedState extends ConsumerState<_ChatFeed> {
  /// The chat list's controller, read once: [ref] is gone by the time the
  /// state is (Riverpod throws on a ref read after dispose, and the list's
  /// last words are said in [deactivate] and [dispose] without one).
  late final RoomChatController _chat;

  /// The memory the list leaves its place in for the list the next layout
  /// builds; read once for the same reason.
  late final RoomChatListMemory _memory;

  /// The scroll, so the feed knows when the viewer is reading away from the
  /// bottom.
  late final ScrollController _scroll;

  /// This room's key, as [build] last saw it: the memory is taken only for
  /// the room it was saved in.
  String _roomKey = '';

  /// Whether the list follows the newest line. False while the viewer reads
  /// away from the bottom: the list then holds the lines it showed, so the
  /// feed's cap cannot pull the row under their eye away.
  bool _following = true;

  /// The lines shown while paused, oldest first.
  List<LiveMessage> _shown = const [];

  /// The feed's count of added lines when [_shown] was last seen.
  int _seen = 0;

  /// The feed's count of removals already applied to [_shown].
  int _removals = 0;

  /// The first message that arrived while the viewer was scrolled away: the
  /// 「以下为新消息」 line is drawn above it, and it clears when they come
  /// back down. Null is everything seen.
  String? _boundaryId;

  /// How many messages arrived while the viewer was reading away from the
  /// bottom. The boundary line says *where* they stopped; this says how much
  /// passed and carries the press that takes them back.
  int _unseen = 0;

  @override
  void initState() {
    super.initState();
    _chat = ref.read(roomChatProvider.notifier);
    _memory = ref.read(roomChatListMemoryProvider);
    // Back where it was left (a turn, the fullscreen switch): the lines it
    // held, the place and the marks — for the room they were saved in. What
    // the feed added or dropped since is applied at once below (the
    // reference's B09 c4: the offset is not left to the page storage, which
    // keys by place in the tree).
    final restore =
        _memory.paused && _memory.roomKey.isNotEmpty && _memory.roomKey == ref.read(roomProvider).room?.identityKey;
    if (restore) {
      _following = false;
      _shown = _memory.shown;
      _seen = _memory.seen;
      _removals = _memory.removals;
      _unseen = _memory.unseen;
      _boundaryId = _memory.boundaryId;
    }
    _scroll = ScrollController(initialScrollOffset: restore ? _memory.offset : 0)..addListener(_onScroll);
    // Arrivals while the viewer is away set the boundary once — the oldest
    // unseen message — and are counted on every burst until they come back
    // down; a list that stays put adds nothing to read.
    ref.listenManual(roomChatProvider, _onChat);
    if (restore) _onChat(null, ref.read(roomChatProvider));
  }

  @override
  void deactivate() {
    // Leaving the tree (a turn, the fullscreen switch, the room closing):
    // what it held and where it was, for the list built in its place. No
    // [ref] here — the fields were read once in initState.
    _memory
      ..roomKey = _roomKey
      ..paused = !_following && _scroll.hasClients
      ..offset = _scroll.hasClients ? _scroll.offset : 0
      ..boundaryId = _boundaryId
      ..unseen = _unseen
      ..shown = _shown
      ..seen = _seen
      ..removals = _removals;
    super.deactivate();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// The list moved: at the bottom it follows the feed again, past the
  /// reading mark it holds what it showed and lets the arrivals pile up.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset <= 2) {
      if (_following && _boundaryId == null && _unseen == 0) return;
      setState(() {
        _following = true;
        _shown = const [];
        _boundaryId = null;
        _unseen = 0;
      });
      return;
    }
    if (_following && _scroll.offset > 40) {
      // Reading away from the newest line: hold the lines as they are, so
      // the feed's cap cannot pull the row under the viewer's eye away; what
      // the feed drops or adds from here on is applied to the held lines.
      // The counters are read after a flush, so they describe the lines on
      // screen and not ones still waiting for the frame.
      _chat.flush();
      final shown = ref.read(roomChatProvider);
      setState(() {
        _following = false;
        _shown = List.of(shown);
        _seen = _chat.added;
        _removals = _chat.removals;
      });
    }
  }

  /// The feed changed (at most once a frame): a following list shows it as
  /// it is; a paused one applies the removals and the combos' replacements
  /// to the lines it holds, and counts what arrived.
  void _onChat(List<LiveMessage>? previous, List<LiveMessage> next) {
    if (!mounted || _following) return;
    // The feed was emptied under the held lines (a new room opened): the
    // held lines are of a room that is gone, and the marks with them.
    if (_chat.added < _seen) {
      setState(() {
        _following = true;
        _shown = const [];
        _seen = _chat.added;
        _removals = _chat.removals;
        _boundaryId = null;
        _unseen = 0;
      });
      return;
    }
    var shown = _shown;
    if (_chat.removals != _removals) {
      // Blocked and recalled lines go from the held list too — also those
      // whose tests the feed no longer keeps (the reference's
      // removalsSince).
      final tests = _chat.removalsSince(_removals) ?? const [];
      _removals = _chat.removals;
      shown = [
        for (final line in shown)
          if (!tests.any((test) => test(line))) line,
      ];
    }
    // A merged gift shows its new count where it stood (the reference's
    // D07.1); a combo's replace is not an arrival.
    shown = [for (final line in shown) _chat.replacementOf(line) ?? line];
    final arrivals = _chat.added - _seen;
    _seen = _chat.added;
    if (identical(shown, _shown) && arrivals == 0) return;
    setState(() {
      _shown = shown;
      if (arrivals > 0) {
        _unseen += arrivals;
        // The feed is capped, so a burst can push the oldest talk out; the
        // count is of what arrived, not of what still has a row to read.
        _boundaryId ??= next.last.messageId;
      }
    });
  }

  /// The floating count's press: back to the newest line. The list is reversed,
  /// so the bottom is offset zero, and the listener clears the count on the way.
  void _toBottom() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_boundaryId == null && _unseen == 0) return;
    setState(() {
      _boundaryId = null;
      _unseen = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final chat = ref.watch(roomChatProvider);
    final standing = ref.watch(roomProvider.select((state) => state.chat));
    final roomKey = ref.watch(roomProvider.select((state) => state.room?.identityKey ?? ''));
    _roomKey = roomKey;
    final anchorName = ref.watch(roomProvider.select((state) => state.room?.anchor?.name ?? ''));
    // While the viewer reads away from the bottom, what they read is the held
    // list, not the feed's — the feed keeps capping, and the row under their
    // eye must not be pulled away by it.
    final lines = _following || _shown.isEmpty ? chat : _shown;
    if (lines.isEmpty) {
      // An empty list is four different facts, and only one of them is the
      // room being quiet: the standing the controller publishes says which, so
      // a refused handshake never reads as "nobody is talking".
      return _chatStateArea(
        child: switch (standing.status) {
          RoomChatStatus.connecting => Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s12,
            children: [
              const DsSpinner(style: DsSpinnerStyle(size: 24)),
              Text(t.room.chatConnecting, style: DsTheme.of(context).typography.small),
            ],
          ),
          RoomChatStatus.unsupported => DsEmptyState(
            icon: const DsIcon(DsIcons.messageCircle),
            title: Text(t.room.chatUnsupported),
          ),
          RoomChatStatus.failed => DsEmptyState(
            icon: const DsIcon(DsIcons.cloudOff),
            title: Text(t.room.chatFailedTitle),
            description: Text(t.room.danmakuConnectFailed(reason: standing.error ?? '')),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => unawaited(ref.read(roomProvider.notifier).retryChat()),
                child: Text(t.common.retry),
              ),
            ],
          ),
          RoomChatStatus.connected => DsEmptyState(
            icon: const DsIcon(DsIcons.messageCircle),
            title: Text(t.room.noChat),
          ),
        },
      );
    }
    // Reversed: item 0 sits at the bottom, so new messages stay in view
    // without a scroll command, and scrolling up leaves the list where the
    // viewer put it. The boundary message — the oldest unseen one — carries
    // the 「以下为新消息」 line above it, so what arrived while the viewer
    // read earlier talk is said, not implied.
    final boundary = _boundaryId;
    final list = ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final message = lines[lines.length - 1 - index];
        // The line above is the older one: the list is reversed, so index + 1
        // is the message the eye reads first, and the pair a run is judged on.
        final above = index + 1 < lines.length ? lines[lines.length - 2 - index] : null;
        final line = _ChatLine(
          message: message,
          anchorName: anchorName,
          repeats: above != null && _continuesSpeaker(above, message),
        );
        if (boundary == null || message.messageId != boundary) return line;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  const Expanded(child: DsDivider()),
                  Text(
                    t.room.newMessagesBelow,
                    style: DsTheme.of(context).typography.overline
                        .copyWith(color: DsTheme.colorsOf(context).textSubtle),
                  ),
                  const Expanded(child: DsDivider()),
                ],
              ),
            ),
            line,
          ],
        );
      },
    );
    // A list that already holds talk never shows the empty state, so the
    // socket's own trouble would go unsaid: the column would simply stop
    // moving, and a viewer cannot tell a quiet room from a dead connection.
    // One line above the list says which it is, with the retry the empty
    // state offers.
    final trouble = switch (standing.status) {
      RoomChatStatus.connecting => (words: t.room.chatConnecting, busy: true),
      RoomChatStatus.failed => (words: t.room.danmakuConnectFailed(reason: standing.error ?? ''), busy: false),
      _ => null,
    };
    if (trouble == null) return _withJumpToBottom(context, list);
    final colors = DsTheme.colorsOf(context);
    return _withJumpToBottom(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, 0),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                if (trouble.busy)
                  const DsSpinner(style: DsSpinnerStyle(size: 14))
                else
                  DsIcon(DsIcons.cloudOff, size: 14, color: colors.warning.text),
                Expanded(
                  child: Text(
                    trouble.words,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTheme.of(context).typography.small.copyWith(color: colors.textMuted),
                  ),
                ),
                if (!trouble.busy)
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(ref.read(roomProvider.notifier).retryChat()),
                    child: Text(t.common.retry),
                  ),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      ),
    );
  }

  /// The feed with the floating unread count over it, when there is one.
  ///
  /// The boundary line inside the list says *where* the viewer stopped; it says
  /// nothing about how much went past, and leaves no way back down but dragging.
  /// The count and the press are the missing half.
  Widget _withJumpToBottom(BuildContext context, Widget feed) {
    if (_unseen <= 0) return feed;
    final words = context.t.room.newMessagesCount(count: _unseen);
    return Stack(
      children: [
        feed,
        PositionedDirectional(
          bottom: DsSpace.s12,
          end: DsSpace.s12,
          child: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: _toBottom,
            child: Text(words),
          ),
        ),
      ],
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
    // The field owns the column's bottom: a hairline above it says where the
    // conversation ends and the viewer's own voice begins.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: DsTheme.colorsOf(context).border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: DsTextField(
                controller: _field,
                clearable: true,
                placeholder: t.room.sendHint,
                onSubmitted: (word) => unawaited(_send(word)),
                style: DsTextFieldStyle(borderRadius: BorderRadius.circular(DsRadii.pill)),
              ),
            ),
            DsButton(onPressed: () => unawaited(_send(_field.text)), child: Text(t.room.send)),
          ],
        ),
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

/// Whether [message] is the same speaker's next plain line after [above] — the
/// run a chat column stops re-labelling. Anything paid, a notice or a membership
/// card is not a `chat` line, so the run's own type test already breaks on them
/// — and so does another sender, because the line that follows has to say what
/// it is again.
bool _continuesSpeaker(LiveMessage above, LiveMessage message) {
  if (message.type != LiveMessageType.chat || above.type != LiveMessageType.chat) return false;
  final name = message.sender?.userName.trim() ?? '';
  return name.isNotEmpty && name == above.sender?.userName.trim();
}

/// One chat line: the sender and the text, the platform's own colour when
/// it gave one. Its context menu copies the line, blocks the sender, or
/// blocks a keyword to cut out of the line.
final class _ChatLine extends ConsumerWidget {
  const _ChatLine({required this.message, this.anchorName = '', this.repeats = false});

  final LiveMessage message;

  /// The room's streamer: a gift names its receiver only when it differs.
  final String anchorName;

  /// Whether the line above is the same speaker's own talk. A run of messages
  /// from one person says who it is once: the second line keeps the column's
  /// indent and drops the face, the badges and the name.
  final bool repeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sender = message.sender;
    var nameStyle = theme.typography.caption;
    final senderName = sender?.userName.trim() ?? '';
    final showNames = ref.watch(chatNamesProvider);
    final showAvatars = ref.watch(chatAvatarsProvider);
    final fontSize = ref.watch(chatListFontSizeProvider);
    final lineSpacing = ref.watch(chatListLineSpacingProvider);
    final height = switch (lineSpacing) {
      'compact' => 1.4,
      'loose' => 1.7,
      _ => 1.5,
    };
    final vertical = switch (lineSpacing) {
      // The tightest step on the spacing scale: a compact list still needs
      // lines that read apart.
      'compact' => 1.0,
      'loose' => DsSpace.s6,
      _ => DsSpace.s3,
    };
    final lineStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? fontSize.toDouble() : null,
      height: height,
      color: colors.text,
    );
    // The sender leads the line: a touch heavier than the words, so the eye
    // lands on who is talking before it reads what was said. The ink is the
    // name's own, never the words': most platforms send white, and white
    // names vanish on a pale panel.
    //
    // Who speaks is said before what is said: the streamer and the staff wear
    // the room's own two inks — the same accent and green the role chips carry —
    // so a moderator's line reads apart in a column of hundreds without the
    // chip being needed. Everyone else keeps the colour the platform sent.
    final roleInk = switch (sender?.role) {
      LiveAnchorRole.anchor => colors.accent,
      LiveAnchorRole.moderator => colors.success.text,
      LiveAnchorRole.platform => colors.info.text,
      _ => null,
    };
    nameStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? fontSize.toDouble() : null,
      height: height,
      fontWeight: FontWeight.w600,
      color:
          roleInk ??
          _senderNameInk(
            sender: sender,
            messageColor: message.color,
            background: colors.surface,
            fallback: colors.textMuted,
          ),
    );
    // The line's own pixel size, followed from the theme when the viewer
    // hasn't picked one; an emoticon rides a touch larger than its words.
    final fontPx = fontSize > 0 ? fontSize.toDouble() : (theme.typography.caption.fontSize ?? 13);
    // The face rides the line's own size: a fixed disc beside a 12px line reads
    // as a plate bolted on, and one that follows the viewer's chat size keeps the
    // column's left edge in proportion with the rest of it.
    final avatarSize = (fontPx * 1.55).clamp(18.0, 26.0);
    final avatarUrl = (sender?.avatarUrl ?? '').trim();
    final gift = _giftOf(message);
    final superChat = message.type == LiveMessageType.superChat && message.payload is LiveSuperChatMessage
        ? message.payload! as LiveSuperChatMessage
        : null;
    final replayed = message.messageId.startsWith('local-replay-');
    final valueInYuan = ref.watch(chatGiftValueInYuanProvider);
    final words = gift == null ? message.text : _giftSentence(t, gift, anchorName, inYuan: valueInYuan);
    // The room's own notices (the platform's notice and system lines) sit
    // apart from the conversation: centred, quiet, no "系统:" voice. A chat
    // message whose platform lost the sender's name is NOT a notice — it
    // stays in the flow, left-aligned, as written.
    final isSystem =
        gift == null &&
        superChat == null &&
        (message.type == LiveMessageType.notice || message.type == LiveMessageType.system);
    // Who is talking, in the room's own terms: the badge pictures the platform
    // sent, the role it declares, the fan medal (its name and level) and the
    // viewer's level. A line with none of them shows none.
    final fanBadgeName = (sender?.fanBadgeName ?? '').trim();
    final fanBadgeLevel = (sender?.fanBadgeLevel ?? '').trim();
    final userLevel = (sender?.userLevel ?? '').trim();
    // A platform can wear several (a title, a medal, an event mark); three is
    // what the line can carry before the name itself is pushed off the front.
    final badgeUrls = [for (final badge in (sender?.badges ?? const <LiveBadge>[]).take(3)) badge.url.trim()];
    final roleTag = switch (sender?.role) {
      LiveAnchorRole.anchor => t.room.roleAnchor,
      LiveAnchorRole.moderator => t.room.roleModerator,
      LiveAnchorRole.platform => t.room.rolePlatform,
      _ => null,
    };
    final showBadges =
        showNames &&
        !isSystem &&
        !repeats &&
        (badgeUrls.isNotEmpty || roleTag != null || fanBadgeName.isNotEmpty || userLevel.isNotEmpty);
    // One height for every tag on the line, tied to the viewer's own chat size:
    // tags of three different heights are what made the column look broken.
    final tagHeight = (fontPx * 1.3).clamp(14.0, 22.0);
    final badgeStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? math.max(fontSize - 2, 9).toDouble() : 10,
      height: 1,
    );
    // The level is a number, not a plate: it reads as a fact once it carries no
    // background, and the plate colour belongs to the medals that earn one.
    final level = int.tryParse(userLevel) ?? 0;
    final levelInk = level >= 20
        ? colors.accent
        : level >= 10
        ? colors.warning.text
        : colors.textSubtle;
    if (isSystem) {
      // A notice is not conversation: it sits in a quiet chip of its own, so
      // the flow of talk reads as talk and the room's own voice reads apart.
      final line = Padding(
        padding: EdgeInsets.symmetric(vertical: vertical),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: 1),
            decoration: BoxDecoration(
              color: colors.control.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(DsRadii.pill),
            ),
            child: Text(
              words,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                fontSize: fontSize > 0 ? math.max(fontSize - 1, 10).toDouble() : null,
                height: height,
                color: colors.textSubtle,
              ),
            ),
          ),
        ),
      );
      return DsContextMenuRegion(
        semanticLabel: t.room.messageActions,
        items: [
          DsMenuItem(
            leading: const DsIcon(DsIcons.copy),
            label: Text(t.room.copy),
            onPressed: () => unawaited(copyRoomMessageText(context, words)),
          ),
        ],
        child: _ChatHover(child: line),
      );
    }
    // A paid line — a gift or a super chat — sits in a tinted banner; plain
    // talk is a bare line, so the column keeps live chat's own density.
    final paid = gift != null || superChat != null;
    final priceText = superChat == null ? null : _superChatPrice(superChat);
    // Who is talking, on its own line: the platform's marks, the role it
    // declares, the fan medal and the level, then the name in its own ink —
    // and the words on the line below, starting at the same edge. The old
    // single flow — badges, name and words jammed into one run — read as a
    // pile of pills in front of a sentence; two lines give the eye a who,
    // then a what, the way the reference's own columns draw them.
    final showNameLine = showNames && senderName.isNotEmpty && !repeats;
    final nameLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBadges) ...[
          // The platform's own pictures first, then the role it declares,
          // then the medal and the level: the order a viewer reads a
          // stranger by.
          for (final url in badgeUrls)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
              child: _BadgeImage(url: url, height: tagHeight),
            ),
          if (roleTag != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
              child: _SenderTag(
                text: roleTag,
                background: switch (sender?.role) {
                  LiveAnchorRole.anchor => colors.accent.withValues(alpha: 0.16),
                  LiveAnchorRole.moderator => colors.success.tint,
                  _ => colors.info.tint,
                },
                foreground: switch (sender?.role) {
                  LiveAnchorRole.anchor => colors.accent,
                  LiveAnchorRole.moderator => colors.success.text,
                  _ => colors.info.text,
                },
                style: badgeStyle,
                height: tagHeight,
              ),
            ),
          if (fanBadgeName.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
              child: _SenderTag(
                text: fanBadgeLevel.isEmpty ? fanBadgeName : '$fanBadgeName $fanBadgeLevel',
                background: colors.accent.withValues(alpha: 0.12),
                foreground: colors.accent,
                // A tint alone disappears on a pale panel.
                border: colors.accent.withValues(alpha: 0.32),
                style: badgeStyle,
                height: tagHeight,
              ),
            ),
          if (userLevel.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
              // The level as the reference draws it: a hairline plate in the
              // tier's own ink, not a bare number.
              child: _SenderTag(
                text: 'Lv.$userLevel',
                background: levelInk.withValues(alpha: 0.10),
                foreground: levelInk,
                border: levelInk.withValues(alpha: 0.55),
                style: badgeStyle.copyWith(fontWeight: FontWeight.w600),
                height: tagHeight,
              ),
            ),
        ],
        Flexible(
          child: Text(senderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
        ),
      ],
    );
    Widget content = Padding(
      padding: EdgeInsets.symmetric(vertical: paid ? 2 : vertical),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The face leads, then the money, then the words: a column of text
          // only is what made the list read as a log. A sender the platform
          // sent no picture for keeps the disc with their initial on it, so
          // every line still starts at the same edge.
          if (showAvatars && senderName.isNotEmpty && repeats)
            // The run keeps its indent: the words of a repeated line start
            // under the first one's, not under the face above.
            SizedBox(width: avatarSize + DsSpace.s6)
          else if (showAvatars && senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1, end: DsSpace.s6),
              child: DsAvatar(
                image: avatarUrl.isEmpty
                    ? null
                    : cachedImage(
                        avatarUrl,
                        policy: ImageCachePolicies.userAvatar,
                        width: (avatarSize * 2).round(),
                        height: (avatarSize * 2).round(),
                      ),
                initials: avatarInitials(senderName),
                toneIndex: DsAvatar.toneFor(senderName),
                semanticLabel: senderName,
                style: DsAvatarStyle(diameter: avatarSize),
              ),
            ),
          if (gift != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1, end: DsSpace.s6),
              child: _GiftIcon(gift: gift, size: fontSize > 0 ? fontSize.toDouble() : 16),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 1,
              children: [
                if (showNameLine) nameLine,
                // The words with the platform's own emoticons in them, cut
                // out of the flying layer's catalogue and drawn as itself -
                // and, for what the catalogue does not carry, the pictures
                // this message names.
                Text.rich(
                  TextSpan(
                    children: [
                      if (priceText != null) ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
                            child: _SenderTag(
                              text: priceText,
                              background: colors.warning.fill,
                              foreground: colors.warning.onFill,
                              style: badgeStyle.copyWith(fontWeight: FontWeight.w600),
                              height: tagHeight,
                            ),
                          ),
                        ),
                      ],
                      if (replayed)
                        TextSpan(
                          text: '[${t.room.replayed}] ',
                          style: nameStyle.copyWith(color: colors.textSubtle),
                        ),
                      ...chatWordSpans(words, lineStyle, fontPx * 1.2, emotes: message.emotes.toList(growable: false)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (superChat != null) {
      // A super chat is the loudest money in the room: the warm banner and
      // the price chip up front, the words beside them. The platform's own
      // colours lead when it sends them (five platforms do, for the card the
      // viewer paid for); the theme's warm tint is the fallback, not the rule.
      final banner = paidBanner(superChat.display.backgroundColor, colors.surface);
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s6),
          decoration: BoxDecoration(
            color: banner?.fill ?? colors.warning.tint,
            borderRadius: BorderRadius.circular(theme.radii.card),
            border: Border.fromBorderSide(
              BorderSide(color: banner?.edge ?? colors.warning.fill.withValues(alpha: 0.35)),
            ),
          ),
          child: content,
        ),
      );
    } else if (gift != null) {
      // A gift is money on the page: the same warm banner the super chat
      // wears, so every paid line reads as money at a glance. Both banners
      // wear the theme's card corner, not a radius of their own.
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s5),
        decoration: BoxDecoration(
          color: colors.warning.tint,
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.fromBorderSide(BorderSide(color: colors.warning.fill.withValues(alpha: 0.35))),
        ),
        child: content,
      );
    }
    return DsContextMenuRegion(
      semanticLabel: t.room.messageActions,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(t.room.copy),
          // Who said it is half of what a quoted line says, so the name rides
          // along for every kind of line, and what is copied is what the column
          // showed — not the platform's raw text with its emoticon codes in it.
          onPressed: () => unawaited(copyRoomMessageText(context, senderName.isEmpty ? words : '$senderName: $words')),
        ),
        // A masked name (`观***`, what a guest sees of a Bilibili viewer) is not
        // an identity: the shield's list reads it as every viewer whose name
        // starts the same way, so this row would offer to hide a crowd.
        if (!message.isLocal && senderName.isNotEmpty && !DanmakuBlockList.isMaskedName(senderName))
          DsMenuItem(
            leading: const DsIcon(DsIcons.ban),
            label: Text(t.room.blockUser),
            onPressed: () => unawaited(blockRoomMessageSender(context, ref, senderName)),
          ),
        if (!message.isLocal)
          DsMenuItem(
            leading: const DsIcon(DsIcons.shield),
            label: Text(t.room.blockKeyword),
            onPressed: () => unawaited(blockRoomMessageKeyword(context, ref, message.text)),
          ),
      ],
      child: _ChatHover(child: content),
    );
  }
}

/// The hover ink under a chat line.
///
/// Every line carries actions — a right click on the desktop, a long press on
/// touch — and a bare line of text never says so (§20.2: a control's reach is
/// shown by hover or focus, not by luck). The fill is the theme's own hover
/// colour at half strength, so the row reads like every other row in the app
/// and never fights a paid line's banner underneath it.
final class _ChatHover extends StatefulWidget {
  const _ChatHover({required this.child});

  final Widget child;

  @override
  State<_ChatHover> createState() => _ChatHoverState();
}

final class _ChatHoverState extends State<_ChatHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered ? colors.hover.withValues(alpha: 0.5) : OnVideoColors.clear,
          borderRadius: theme.radii.controlCorners(null, 24),
        ),
        child: widget.child,
      ),
    );
  }
}

/// The filled-in name inks, keyed by the platform colour and the ground it
/// was measured against: the same few colours come back all night, so the
/// walk over lightness runs once per pair rather than once per line.
final Map<(int, int), Color> _nameInks = {};

/// The ink a sender's name is written in on [background]: the platform's own
/// name colour (17LIVE), else the colour a coloured danmaku carries. White
/// and black are no colour at all — those lines take [fallback] — and any
/// other is walked towards black or white until it clears 4.5:1, so a name
/// never sinks into the panel it sits on. The reference's `chatNameInk`.
Color _senderNameInk({
  required MessageSender? sender,
  required LiveMessageColor? messageColor,
  required Color background,
  required Color fallback,
}) {
  final source = sender?.nameColor ?? messageColor;
  final named = source == null ? null : (r: source.r, g: source.g, b: source.b);
  if (named == null ||
      (named.r == 255 && named.g == 255 && named.b == 255) ||
      (named.r == 0 && named.g == 0 && named.b == 0)) {
    // The platform gave nothing readable: the name takes a hue of its own,
    // hashed from the name so one speaker keeps one colour — the reference's
    // column reads many hues, not a wall of grey.
    final ground = background.withValues(alpha: 1);
    final dark = ground.computeLuminance() < 0.35;
    final seed = (sender?.userName.trim().isEmpty ?? true) ? 0 : sender!.userName.trim().codeUnitAt(0);
    final hue = (seed * 47) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.58, dark ? 0.70 : 0.42).toColor();
  }
  final color = Color.fromARGB(255, named.r, named.g, named.b);
  final ground = background.withValues(alpha: 1);
  final key = (color.toARGB32(), ground.toARGB32());
  if (_nameInks[key] case final known?) return known;
  if (_nameInks.length >= 512) _nameInks.clear();
  return _nameInks[key] = _readableNameInk(color, ground);
}

/// [color] kept as it is when it clears 4.5:1 on [background], else moved
/// one percent at a time towards black or white — whichever that surface
/// stands further from, where one of them always lands.
Color _readableNameInk(Color color, Color background) {
  double contrast(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
  }

  if (contrast(color, background) >= 4.5) return color;
  final darker = InkOnColor.darkInkOn(background);
  final hsl = HSLColor.fromColor(color);
  var lightness = hsl.lightness;
  while (true) {
    lightness = (lightness + (darker ? -0.01 : 0.01)).clamp(0.0, 1.0);
    final next = hsl.withLightness(lightness).toColor();
    if (contrast(next, background) >= 4.5 || lightness == 0 || lightness == 1) return next;
  }
}

/// The [LiveGift] a platform gift line carries; null for anything else (a
/// local gift carries a map and keeps its plain text).
LiveGift? _giftOf(LiveMessage message) =>
    message.type == LiveMessageType.gift && message.payload is LiveGift ? message.payload! as LiveGift : null;

/// The price as the platform writes it for others to see ("￥12"); null when
/// the card has none of its own.
String? _superChatPrice(LiveSuperChatMessage message) {
  final shown = message.price.displayText.trim();
  if (shown.isNotEmpty) return shown;
  final amount = message.price.amount;
  if (amount == null || amount <= 0) return null;
  return [?message.price.currency, '$amount'].join();
}

/// The value of the whole line in the gift's unit, when it has one: a free
/// gift, an unknown unit and a platform without a price show nothing.
int? _giftShownValue(LiveGift gift) {
  if (giftUnitIsFree(gift.value.unit)) return null;
  final shown = giftShownCount(gift);
  final unitPrice = gift.value.unitPrice;
  if (shown > gift.count && unitPrice != null && unitPrice > 0) return (unitPrice * shown).round();
  final total = gift.value.totalValue;
  if (total == null || total <= 0) return null;
  return total.round();
}

/// A fen amount as yuan, without trailing zeros ("100", "0.5", "12.34").
String _yuanText(int fen) {
  if (fen % 100 == 0) return '${fen ~/ 100}';
  final text = (fen / 100).toStringAsFixed(2);
  final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// The units whose rate in yuan a platform fixes, so "礼物价值换算成元" can
/// write them as yuan; the overseas rates only rank gifts and stay in their
/// own unit (the reference's A08.12 list, plus our [LiveGiftUnit.rmb]).
const Set<LiveGiftUnit> _giftYuanUnits = {
  LiveGiftUnit.fen,
  LiveGiftUnit.rmb,
  LiveGiftUnit.yuan,
  LiveGiftUnit.goldSeed,
  LiveGiftUnit.diamond,
  LiveGiftUnit.douyinCoin,
  LiveGiftUnit.acCoin,
  LiveGiftUnit.starCoin,
};

String? _giftValueText(Translations t, LiveGift gift, {bool inYuan = false}) {
  final value = _giftShownValue(gift);
  if (value == null || value <= 0) return null;
  final room = t.room;
  if (inYuan && _giftYuanUnits.contains(gift.value.unit)) {
    final rate = giftUnitsPerYuan[gift.value.unit]!;
    // At least a fen: a paid gift is never "0 元".
    final fen = math.max(1, (value * 100 / rate).round());
    return room.giftValueYuan(value: _yuanText(fen));
  }
  return switch (gift.value.unit) {
    LiveGiftUnit.fen => room.giftValueYuan(value: _yuanText(value)),
    LiveGiftUnit.rmb || LiveGiftUnit.yuan => room.giftValueYuan(value: '$value'),
    LiveGiftUnit.goldSeed => room.giftValueGoldSeed(value: '$value'),
    LiveGiftUnit.diamond => room.giftValueDiamond(value: '$value'),
    LiveGiftUnit.redBean => room.giftValueRedBean(value: '$value'),
    LiveGiftUnit.point => room.giftValuePoint(value: '$value'),
    LiveGiftUnit.bits => room.giftValueBits(value: '$value'),
    LiveGiftUnit.kicks => room.giftValueKicks(value: '$value'),
    LiveGiftUnit.cheese => room.giftValueCheese(value: '$value'),
    LiveGiftUnit.starBalloon => room.giftValueStarBalloon(value: '$value'),
    LiveGiftUnit.douyinCoin => room.giftValueDouyinCoin(value: '$value'),
    LiveGiftUnit.sixCoin => room.giftValueSixCoin(value: '$value'),
    LiveGiftUnit.acCoin => room.giftValueAcCoin(value: '$value'),
    LiveGiftUnit.starCoin => room.giftValueStarCoin(value: '$value'),
    LiveGiftUnit.heart => room.giftValueHeart(value: '$value'),
    LiveGiftUnit.note => room.giftValueNote(value: '$value'),
    LiveGiftUnit.free || LiveGiftUnit.silver || LiveGiftUnit.banana || LiveGiftUnit.gold || LiveGiftUnit.other => null,
  };
}

/// The gift in words: "送出 小心心 ×3", plus its value when known.
String _giftSentence(Translations t, LiveGift gift, String anchorName, {bool inYuan = false}) {
  final value = _giftValueText(t, gift, inYuan: inYuan);
  final words = giftSentenceText(t, gift, anchorName);
  return value == null ? words : '$words  $value';
}

/// A small inline chip on a chat line: a fan badge (its name and level) or
/// the viewer's level, in the platform's own labels.
/// One sender tag beside the name: the platform's fan medal, the room role, the
/// price of a paid line.
///
/// A rectangle, not a pill — the platforms draw their medals as plates, and a
/// row of pills on every line reads as a row of buttons. The height is locked
/// to the line's own size so a tag never pushes the next line down, and the
/// digits ride the numeric face so `Lv.9` and `Lv.24` take the same width.
final class _SenderTag extends StatelessWidget {
  const _SenderTag({
    required this.text,
    required this.background,
    required this.foreground,
    required this.style,
    required this.height,
    this.border,
  });

  final String text;
  final Color background;
  final Color foreground;
  final TextStyle style;

  /// The tag's own height; the corners follow it, the way a control's do.
  final double height;

  /// A hairline in the tag's own hue: a tint alone disappears on a pale panel.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: theme.radii.controlCorners(null, height),
        border: border == null ? null : Border.fromBorderSide(BorderSide(color: border!)),
      ),
      child: Text(text, style: style.apply(color: foreground), maxLines: 1),
    );
  }
}

/// One badge picture the platform sent (a guard crest, a VIP mark, a title).
///
/// Where a platform gives an image, this app draws that image rather than
/// inventing a label for something it cannot name; a URL that fails or is not
/// http leaves nothing behind, so a broken badge never punches a hole in a line.
final class _BadgeImage extends StatelessWidget {
  const _BadgeImage({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return const SizedBox.shrink();
    // A fixed slot: badges are mostly wider than tall, and a line must not
    // reflow when the picture arrives.
    return SizedBox(
      height: height,
      width: height * 1.5,
      child: Image(
        image: cachedImage(url, policy: ImageCachePolicies.chatEmote, height: (height * 2).round()),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// A gift's picture at its line's text size, with the generic gift mark
/// when the platform gave none or it failed to load.
final class _GiftIcon extends StatelessWidget {
  const _GiftIcon({required this.gift, required this.size});

  final LiveGift gift;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final fallback = DsIcon(DsIcons.gift, size: size, color: colors.textSubtle);
    final url = gift.iconUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return fallback;
    return Image(
      image: cachedImage(
        url,
        policy: ImageCachePolicies.chatEmote,
        width: (size * 2).round(),
        height: (size * 2).round(),
      ),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// The flying layer's master switch and the way into its settings page: the
/// layer has one set of controls, in the settings centre, and a room opens
/// that page rather than a second copy of it.
final class _RoomDanmakuSettings extends ConsumerWidget {
  const _RoomDanmakuSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s20),
      children: [
        DsSwitch(
          value: settings.danmakuVisible,
          onChanged: (value) => unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: value)),
          label: Text(t.room.danmakuOn),
          description: Text(t.room.danmakuSettingsDesc),
        ),
        const SizedBox(height: DsSpace.s16),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.slidersHorizontal),
              title: Text(t.settings.navDanmaku),
              description: Text(t.settings.danmakuDescription),
              showChevron: true,
              onPressed: () =>
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.danmaku.name).location)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The super chat board: the platform's own list merged with the paid
/// messages and membership cards that arrive while the room is open; a
/// failure names the reason and offers a retry.
final class _SuperChatTab extends ConsumerWidget {
  const _SuperChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final board = ref.watch(roomSuperChatsProvider);
    void retry() => unawaited(ref.read(roomProvider.notifier).reloadSuperChats());
    if (board.loading && board.messages.isEmpty) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
    }
    final error = board.error;
    if (error != null && board.messages.isEmpty) {
      return _chatStateArea(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.badgeDollarSign),
          title: Text(t.room.superChatFailed),
          description: Text(error),
          actions: [DsButton(onPressed: retry, child: Text(t.common.retry))],
        ),
      );
    }
    if (board.messages.isEmpty) {
      return _chatStateArea(
        child: DsEmptyState(icon: const DsIcon(DsIcons.badgeDollarSign), title: Text(t.room.superChatEmpty)),
      );
    }
    final messages = board.messages;
    return ListView.separated(
      padding: const EdgeInsets.all(DsSpace.s16),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s8),
      // Newest on top, as the reference's super chat page keeps them.
      itemBuilder: (context, index) => _SuperChatCard(message: messages[messages.length - 1 - index]),
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
    final membership = isMembershipCard(message);
    final price = _superChatPrice(message) ?? '';
    // The price's warmth: the tint deepens with the money on the line, so
    // the board reads by value at a glance (reference's graded cards).
    final amount = message.price.amount ?? 0;
    final tint = amount >= 100
        ? 0.16
        : amount >= 10
        ? 0.10
        : 0.05;
    // The same warmth, in the platform's own two colours when it sends them
    // (the reference paints its super-chat card with exactly these): the money
    // still decides the weight, so the board keeps reading by value, and the
    // row's text keeps the theme's contrast.
    final banner = paidBannerGradient(
      top: message.display.backgroundColor,
      bottom: message.display.backgroundBottomColor,
      surface: colors.surface,
      weight: tint,
    );
    return Container(
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: banner == null
          ? DsBoxDecoration(
              color: colors.accent.withValues(alpha: tint),
              borderRadius: BorderRadius.circular(theme.radii.card),
            )
          : BoxDecoration(gradient: banner, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          // A membership card has no avatar of its own (the reference's
          // D07.2 cards), only the buyer's name.
          if (!membership)
            DsAvatar(
              initials: avatarInitials(name),
              image: face.isEmpty ? null : cachedImage(face, policy: ImageCachePolicies.userAvatar),
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
                    if (price.isNotEmpty) DsBadge(dot: false, label: Text(price), status: DsStatus.warning),
                  ],
                ),
                Text(message.text, style: theme.typography.body.copyWith(color: colors.text)),
                if (_shownAt() case final shown?)
                  Text(shown, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
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

/// The shield inside the room: the compact tag-based panel the chat
/// column's width was squeezing out of the settings pane.
final class _ShieldTab extends StatelessWidget {
  const _ShieldTab();

  @override
  Widget build(BuildContext context) => const RoomShieldPanel();
}

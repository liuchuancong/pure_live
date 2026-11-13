part of 'room_chat.dart';

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
  /// so the bottom is offset zero. The held list is dropped at the same time —
  /// clearing only the count left the widget following its paused copy, so the
  /// press could look like it did nothing when the old offset was already zero.
  void _toBottom() {
    setState(() {
      _following = true;
      _shown = const [];
      _boundaryId = null;
      _unseen = 0;
      _seen = _chat.added;
      _removals = _chat.removals;
    });
    void jump() {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    }

    jump();
    // The rebuild can change the list's extent; jumping again after layout
    // makes the button land at the true bottom rather than the old one.
    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final chat = ref.watch(roomChatProvider);
    final standing = ref.watch(roomProvider.select((state) => state.chat));
    final roomKey = ref.watch(roomProvider.select((state) => state.room?.identityKey ?? ''));
    _roomKey = roomKey;
    final anchorName = ref.watch(roomProvider.select((state) => state.room?.anchor?.name ?? ''));
    final platform = ref.watch(roomProvider.select((state) => state.room?.ref.platform ?? ''));
    // While the viewer reads away from the bottom, what they read is the held
    // list, not the feed's — the feed keeps capping, and the row under their
    // eye must not be pulled away by it.
    // Super chats live in their own tab; the danmaku feed stays plain talk.
    final lines = (_following || _shown.isEmpty ? chat : _shown)
        .where((message) => message.type != LiveMessageType.superChat && !isStandaloneBadgeEcho(message))
        .toList(growable: false);
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
          platform: platform,
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

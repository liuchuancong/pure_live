part of 'room_page.dart';

// State members hosted by an extension: the receiver is the State, so
// its protected setState is safe to call here.
// ignore_for_file: invalid_use_of_protected_member

extension _RoomPageLayouts on _RoomPageState {
  /// The narrow-room layouts and their shared measures: the portrait full
  /// screen with its reachable chat, the phone-held-sideways row, the
  /// picture's own ratio, and the room switching the sideways swipes drive.

  /// The portrait full-screen surface: the same player filling the page. The
  /// picture fills it exactly as the 画面 setting says, and the flying layer
  /// keeps the one danmaku configuration.
  ///
  /// Two buttons used to float here at the top right, and the player's strip
  /// draws its back arrow, its danmaku switch, its presentation cluster and
  /// its ⋮ across the same band — the two rows stood on one another. Both
  /// verbs the row carried are on the strip already: the back arrow leaves the
  /// portrait full screen (`leave` answers that first) and 切换直播间 sits in
  /// the ⋮ beside it.
  Widget _buildPortraitFullscreen(BuildContext context, Widget player, {required bool canSwipeRooms}) {
    final t = context.t;
    // The chat's panel takes the lower ~62% when its door is pressed; the
    // picture keeps the rest, and the danmaku flies over both.
    final panelTop = MediaQuery.sizeOf(context).height * .38;
    return ColoredBox(
      color: OnVideoColors.ground,
      child: Stack(
        children: [
          Positioned.fill(child: player),
          // The chat's temporary panel: the tabs and the composer, glass over
          // the picture. Its handle closes it — a tap, or a swipe down.
          if (_immersiveChatOpen)
            PositionedDirectional(
              top: panelTop,
              start: 0,
              end: 0,
              bottom: 0,
              child: RoomGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _immersiveChatOpen = false),
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) > 120) {
                          setState(() => _immersiveChatOpen = false);
                        }
                      },
                      child: SizedBox(
                        height: 20,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: OnVideoColors.iconDim,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: RoomChatPanel(translucent: true)),
                  ],
                ),
              ),
            ),
          // The door: a pill above the restore zone — a tap opens the panel,
          // not a gesture the chat's own settings could turn off.
          if (!_immersiveChatOpen)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 116,
              child: Center(
                child: PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.messageCircle,
                    label: t.room.expandChat,
                    onPressed: () => setState(() => _immersiveChatOpen = true),
                  ),
                ),
              ),
            ),
          if (canSwipeRooms)
            const PositionedDirectional(
              start: DsSpace.s12,
              end: DsSpace.s12,
              bottom: 28,
              child: IgnorePointer(child: _PortraitSwipeHint()),
            ),
        ],
      ),
    );
  }

  /// The phone's portrait immersive room (the reference's own portrait live
  /// room): the picture fills the page edge to edge, the room's talk rides
  /// over it as pills anchored above the composer bar, and the top chrome is
  /// the capsule. No column, no sheet — the page is the player.
  ///
  /// [player] arrives built with the immersive surface's own arguments (the
  /// capsule's shape, the swipe-to-switch zones, the system fullscreen verb,
  /// the insets the control bar stands on); [onMore] is the composer bar's ⋯,
  /// carrying the clean-screen switch; [canSwipeRooms] lights the swipe hint
  /// the portrait full screen keeps.
  Widget _buildPhoneImmersivePortrait(
    BuildContext context, {
    required Widget player,
    required bool canSwipeRooms,
    required VoidCallback onMore,
  }) {
    // The composer bar's floor: the safe area's bottom (the page opts out of
    // SafeArea, so the layout clears it itself) plus the keyboard while it is
    // up — the bar rides above the keyboard, the pills above the bar, and the
    // control bar above the pills.
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final barBottom = padding.bottom + keyboard;
    final barTop = barBottom + _kImmersiveComposerBarHeight;
    final size = MediaQuery.sizeOf(context);
    final clean = _cleanScreen;
    return ColoredBox(
      color: OnVideoColors.ground,
      child: Stack(
        children: [
          Positioned.fill(child: player),
          // The chat's drawer: the panel with its tabs and composer, glass
          // over the picture. Its handle closes it — a tap, or a swipe down.
          // While it is up (and while the screen is clean) the glance layer
          // stands down: one conversation surface at a time. The keyboard
          // lifts the drawer's composer the way the bar's own floor does.
          if (!clean && _immersiveChatOpen)
            PositionedDirectional(
              top: size.height * .38,
              start: 0,
              end: 0,
              bottom: keyboard,
              child: RoomGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _immersiveChatOpen = false),
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) > 120) {
                          setState(() => _immersiveChatOpen = false);
                        }
                      },
                      child: SizedBox(
                        height: 20,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: OnVideoColors.iconDim,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: RoomChatPanel(translucent: true)),
                  ],
                ),
              ),
            ),
          // The glance layer: the pills over the picture's lower left, the
          // composer bar under them. The pills keep the picture's right edge
          // clear — the corner the reference reserves for its activity card.
          if (!clean && !_immersiveChatOpen) ...[
            PositionedDirectional(
              start: DsSpace.s12,
              end: math.max(72, size.width * 0.18),
              bottom: barTop + DsSpace.s8,
              child: const RoomChatOverlay(),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: barBottom,
              child: _ImmersiveComposerBar(
                onMore: onMore,
                onOpenChat: () => setState(() => _immersiveChatOpen = true),
              ),
            ),
          ],
          // The clean screen's way back: a pill at the picture's left edge,
          // the lock pill's opposite. It stays while the chrome hides, so the
          // viewer is never stranded in the quiet.
          if (clean)
            PositionedDirectional(
              start: DsSpace.s12,
              top: 0,
              bottom: padding.bottom,
              child: Center(
                child: PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.eye,
                    label: context.t.room.cleanScreenExit,
                    onPressed: () => setState(() => _cleanScreen = false),
                  ),
                ),
              ),
            ),
          if (canSwipeRooms)
            PositionedDirectional(
              start: DsSpace.s12,
              end: DsSpace.s12,
              bottom: math.max(28, barTop + DsSpace.s12),
              child: const IgnorePointer(child: _PortraitSwipeHint()),
            ),
        ],
      ),
    );
  }

  /// The phone held sideways, immersive (the reference's landscape full
  /// screen): the picture fills the sideways window and the control bar
  /// carries the room's send. The reference draws no chat column sideways —
  /// the flying layer and the bar's input are the talk's whole surface
  /// there — and the vertical swipe keeps walking the room list.
  Widget _buildPhoneLandscapeImmersive(BuildContext context, {required Widget player, required bool canSwipeRooms}) {
    return ColoredBox(
      color: OnVideoColors.ground,
      child: Stack(
        children: [
          Positioned.fill(child: player),
          if (canSwipeRooms)
            const PositionedDirectional(
              start: DsSpace.s12,
              end: DsSpace.s12,
              bottom: 28,
              child: IgnorePointer(child: _PortraitSwipeHint()),
            ),
        ],
      ),
    );
  }

  /// The picture's frame, from the engine's own geometry: the stream reports
  /// its shape, so the room no longer keeps a per-room manual orientation to
  /// fight it. The clamp keeps an absurd report from taking the whole stage.
  double _pictureRatio(RoomState room) {
    final detected = room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0;
    final ratio = detected <= 0 || !detected.isFinite ? 16 / 9 : detected;
    return ratio.clamp(kRoomFrameRatioMin, kRoomFrameRatioMax);
  }

  /// The portrait fullscreen's vertical swipe: +1 for the next room in the
  /// list the room was opened from, -1 for the previous. A room opened from
  /// no list swipes through the switcher's followed-on-air/history rooms.
  /// The new room opens on this page's controller, so the portrait surface
  /// and the player stay.
  void _switchRoomByStep(int step) {
    if (_switchingPortraitRoom) return;
    final current = ref.read(roomProvider).room;
    if (current == null) return;
    final playlist = ref.read(roomPlaylistProvider);
    final fromSource = playlist != null && playlist.current.ref.identityKey == current.ref.identityKey;
    final target = fromSource ? playlist.neighbour(step) : _switcherSwipeTarget(current, step);
    if (target == null) return;
    _switchingPortraitRoom = true;
    _portraitSwipeTarget = target.ref.identityKey;
    _currentRoomKey = target.ref.identityKey;
    if (fromSource) ref.read(roomPlaylistProvider.notifier).move(step);
    // The switch names itself: a remote's Up or Down leaves no trail on the
    // picture, and the viewer needs to know whose room just came up — the
    // anchor when the list carried one, the title always.
    final nick = target.anchor?.name ?? '';
    final title = target.content.title;
    final named = [nick, title].where((part) => part.isNotEmpty).join(' · ');
    if (named.isNotEmpty) ref.read(roomHintProvider.notifier).show(named);
    unawaited(
      ref
          .read(roomProvider.notifier)
          .open(platform: target.ref.platform, roomId: target.ref.roomId, known: target)
          .whenComplete(() {
            if (mounted) _switchingPortraitRoom = false;
          }),
    );
  }

  /// The neighbour in the switcher's list when the room carries no source
  /// list; a current room absent from it starts from the first/last, as the
  /// switcher panel does.
  LiveRoom? _switcherSwipeTarget(LiveRoom current, int step) {
    final rooms = roomSwipeList(
      follows: ref.read(followsProvider).rooms,
      history: [for (final (room, _) in ref.read(historyProvider).records) room],
      current: current,
    );
    if (rooms.isEmpty) return null;
    final index = rooms.indexWhere((room) => room.ref.identityKey == current.ref.identityKey);
    if (index < 0) return step > 0 ? rooms.first : rooms.last;
    return rooms[(index + step) % rooms.length];
  }
}

/// The immersive composer bar's own height above its padding: one control
/// row and its air, the figure the control bar stands on (`bottomInset`) and
/// the chat pills measure their floor from.
const double _kImmersiveComposerBarHeight = 52;

/// The immersive room's composer bar (the reference's bottom bar): the ⋯
/// that opens the more container, the chat's door, the send field and its
/// emote panel and the send glyph — glass pills over the picture, never a
/// panel of their own. A room whose chat only listens keeps the two pills:
/// a field that cannot send is a lie the bar must not draw.
final class _ImmersiveComposerBar extends ConsumerStatefulWidget {
  const _ImmersiveComposerBar({required this.onMore, required this.onOpenChat});

  /// Opens the room's more container (the page hands its own closure in, so
  /// the clean-screen switch rides the same sheet).
  final VoidCallback onMore;

  /// Opens the chat drawer (the panel with its tabs and composer).
  final VoidCallback onOpenChat;

  @override
  ConsumerState<_ImmersiveComposerBar> createState() => _ImmersiveComposerBarState();
}

final class _ImmersiveComposerBarState extends ConsumerState<_ImmersiveComposerBar> {
  final TextEditingController _field = TextEditingController();

  /// The emote panel: open until the viewer closes it, the composer's own
  /// rule — a picker that shut itself after every face would make a run of
  /// them impossible.
  bool _emotesOpen = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Puts an emote's code where the caret is — or at the line's end when the
  /// field has no say about a caret — and leaves the typing position there.
  void _insertEmote(String code) {
    final text = _field.text;
    final selection = _field.selection;
    final start = selection.start < 0 || selection.start > text.length ? text.length : selection.start;
    final end = selection.end < 0 || selection.end > text.length ? text.length : selection.end;
    _field.value = TextEditingValue(
      text: text.replaceRange(start, end, code),
      selection: TextSelection.collapsed(offset: start + code.length),
    );
  }

  Future<void> _send(String word) async {
    if (word.trim().isEmpty) return;
    final failure = await ref.read(roomProvider.notifier).sendDanmaku(word);
    if (!mounted) return;
    if (failure == null) {
      _field.clear();
    } else {
      // The platform's own reason: a refused send names what refused it.
      showDsToast(context: context, title: context.t.room.sendFailed, description: failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final canSend = ref.watch(roomProvider.notifier).canSendDanmaku;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              PlayerGlassPill(
                child: PlayerBarButton(icon: DsIcons.ellipsis, label: t.common.more, onPressed: widget.onMore),
              ),
              PlayerGlassPill(
                child: PlayerBarButton(
                  icon: DsIcons.messageCircle,
                  label: t.room.chatTitle,
                  onPressed: widget.onOpenChat,
                ),
              ),
              if (canSend) ...[
                Expanded(
                  child: PlayerGlassPill(
                    child: TextField(
                      controller: _field,
                      style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
                      cursorColor: DsTheme.colorsOf(context).accent,
                      maxLength: 100,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (word) => unawaited(_send(word)),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsetsDirectional.symmetric(
                          horizontal: DsSpace.s12,
                          vertical: DsSpace.s8,
                        ),
                        hintText: t.room.sendHint,
                        hintStyle: theme.typography.caption.copyWith(color: OnVideoColors.inkSubtle),
                        counterText: '',
                      ),
                    ),
                  ),
                ),
                PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.smile,
                    label: t.room.emotes,
                    selected: _emotesOpen,
                    onPressed: () => setState(() => _emotesOpen = !_emotesOpen),
                  ),
                ),
                PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.send,
                    label: t.room.send,
                    onPressed: () => unawaited(_send(_field.text)),
                  ),
                ),
              ],
            ],
          ),
          // The faces, over the bar's top edge: the non-clipping Stack lets
          // them stand on the picture, in the player's own dark plate — the
          // app theme's light/dark pick never reaches the picture.
          if (_emotesOpen && canSend)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: _kImmersiveComposerBarHeight - DsSpace.s8,
              child: RoomEmotePanel(onPick: _insertEmote, onVideo: true),
            ),
        ],
      ),
    );
  }
}

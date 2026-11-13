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
          if (_portraitChatOpen)
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
                      onTap: () => setState(() => _portraitChatOpen = false),
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) > 120) {
                          setState(() => _portraitChatOpen = false);
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
          if (!_portraitChatOpen)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 116,
              child: Center(
                child: PlayerGlassPill(
                  child: PlayerBarButton(
                    icon: DsIcons.messageCircle,
                    label: t.room.expandChat,
                    onPressed: () => setState(() => _portraitChatOpen = true),
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

  /// A phone held sideways, outside fullscreen (the reference's `landscape`
  /// layout, its choice A): the picture takes the whole height under the app
  /// bar and the chat's list alone a 280 px column beside it.
  ///
  /// The room's card has no column to sit in here — at the head of the list it
  /// left one line of talk on a phone's short side — so its name folds into the
  /// picture's strip, which opens the details the card would ([player] is built
  /// with that press). The quality and the line stay on the bar under the
  /// picture, where every layout keeps them. The list is the chat panel's own,
  /// drawn without its tabs and composer, so it reads the room's one feed; the
  /// picture is the one surface every layout reparents, so turning the phone
  /// moves it rather than rebuilding it.
  Widget _buildPhoneLandscape(Widget player) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(color: kPlayerStageColor, child: player),
        ),
        const DsDivider.vertical(),
        const SizedBox(width: _RoomPageState._phoneLandscapeChatWidth, child: RoomChatPanel()),
      ],
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

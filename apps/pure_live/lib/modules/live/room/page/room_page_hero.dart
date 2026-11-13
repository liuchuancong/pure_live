part of 'room_page.dart';

/// The word shown on entering the portrait full screen: the one gesture there
/// cannot be seen. Swiping up or down over the picture's middle third moves to
/// the next or previous room in the list this one came from, and nothing else
/// on the surface says so — the ✕ and the switcher button both show
/// themselves.
///
/// It borrows the reference's shape (a pill above the bottom rows, gone after
/// three seconds) and keeps its honesty: it is drawn only where the swipe is
/// actually live, so it can never teach a gesture the settings turned off.
final class _PortraitSwipeHint extends StatefulWidget {
  const _PortraitSwipeHint();

  @override
  State<_PortraitSwipeHint> createState() => _PortraitSwipeHintState();
}

final class _PortraitSwipeHintState extends State<_PortraitSwipeHint> {
  static const Duration _visibleFor = Duration(seconds: 3);

  bool _visible = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _hide = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The fade is the whole animation; with reduce-motion on, the pill is
    // simply gone when its seconds are up.
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: Center(
        child: PlayerGlassPill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
            child: Text(
              context.t.room.portraitSwipeHint,
              textAlign: TextAlign.center,
              style: DsTheme.of(context).typography.caption.copyWith(color: OnVideoColors.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// The wide chat column's identity header: the anchor's card — avatar in its
/// live ring, the name, the platform and area, and the follow pill.
///
/// The three figures (viewers, on air, watched) are not a permanent row: the
/// header keeps one line so the talk gets the height. A pointer hovering the
/// header gets them in a tooltip; a phone reads them in the panel's facts row
/// and the room details.
final class _ChatRoomHeader extends ConsumerWidget {
  const _ChatRoomHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) {
      // The detail hasn't landed: the header keeps its footprint with the
      // quiet blocks the identity strip rests on — a blank strip would jump
      // when the facts arrive.
      return ColoredBox(
        color: colors.surface,
        child: const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DsSkeleton.circle(size: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [DsSkeleton(width: 160, height: 15), DsSkeleton(width: 90, height: 12)],
              ),
              Spacer(),
              DsSkeleton.block(width: 64, height: 28),
            ],
          ),
        ),
      );
    }
    final anchor = (detail.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? detail.content.title : anchor;
    final avatar = (detail.anchor?.avatarUrl ?? detail.content.coverUrl).trim();
    final live = detail.broadcast.isLiveNow;
    final site = ref.watch(sitesProvider).all.where((site) => site.manifest.id == detail.ref.platform).firstOrNull;
    final platform = site == null ? detail.ref.platform : localizedSiteName(site);
    final area = (detail.area?.areaName ?? '').trim();
    final where = [platform, if (area.isNotEmpty) area].join(' · ');
    final caption = theme.typography.caption.copyWith(color: colors.textMuted);
    final header = DsPressable(
      semanticLabel: t.room.detailsHint,
      onPressed: () => unawaited(showRoomDetails(context)),
      builder: (context, states, child) =>
          ColoredBox(color: states.contains(WidgetState.hovered) ? colors.hover : colors.surface, child: child),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
        child: Row(
          spacing: DsSpace.s12,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: live ? colors.accent : colors.border),
              child: DsAvatar(
                initials: avatarInitials(name),
                image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                size: DsSize.md,
                semanticLabel: name,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodyStrong.copyWith(color: colors.text),
                  ),
                  if (where.isNotEmpty) Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                ],
              ),
            ),
            const _FollowPill(),
          ],
        ),
      ),
    );
    final online = detail.audience.onlineViewers ?? detail.audience.totalViewers;
    final started = detail.broadcast.startedAt;
    final watchStarted = ref.watch(roomProvider.select((room) => room.watchStartedAt));
    final figures = <String>[
      if (online != null) '${t.room.statViewers} ${AudienceFormat.format(online)}',
      if (started != null) '${t.room.statOnAir} ${_roomClock(started)}',
      '${t.room.statWatched} ${_roomClock(watchStarted)}',
    ].join('\n');
    return DsTooltip(message: figures, side: DsSide.bottom, child: header);
  }
}

/// A running clock for the header's hover figures, without a ticking widget:
/// the header rebuilds on the room's own updates, and a hover snapshot is
/// enough for a number that is not the thing being watched.
String _roomClock(DateTime since) {
  final elapsed = DateTime.now().difference(since);
  String two(int value) => value.toString().padLeft(2, '0');
  if (elapsed.isNegative) return '00:00:00';
  return '${two(elapsed.inHours)}:${two(elapsed.inMinutes.remainder(60))}:${two(elapsed.inSeconds.remainder(60))}';
}

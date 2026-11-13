part of 'room_page.dart';

/// The compact room that is not a portrait sheet (the reference's fCompact):
/// the picture takes what the panel leaves, the grip drags the panel between
/// its three stops, and the panel itself is the facts row over the chat with
/// the stops' chips at its foot.
///
/// The sheet layout ([RoomBottomPanel]) floats over a full-bleed picture
/// because a portrait stream has no spare height to dock a section into; a
/// landscape or letterboxed stream does, and there the reference keeps the
/// room's parts in a column — picture, grip, panel. A panel that can rest
/// anywhere hands the viewer a third question to answer on every move, so the
/// grip releases onto the nearest of the same three stops the sheet uses, and
/// a pull carried far enough under the lowest one — or a downward flick —
/// hands the room to its portrait full screen, the reference's own door.
final class _CompactRoomBody extends StatefulWidget {
  const _CompactRoomBody({required this.player, required this.ratio, required this.chat, this.onPortraitFullscreen});

  /// The picture, laid out in whatever height the panel leaves.
  final Widget player;

  /// The stream's own shape, kept by the picture's box.
  final double ratio;

  /// The chat column under the facts row.
  final Widget chat;

  /// Enters the room's portrait full screen when the grip is pulled past its
  /// lowest stop and let go; null where the room has none, and the grip then
  /// only springs back.
  final VoidCallback? onPortraitFullscreen;

  @override
  State<_CompactRoomBody> createState() => _CompactRoomBodyState();
}

final class _CompactRoomBodyState extends State<_CompactRoomBody> with SingleTickerProviderStateMixin {
  /// The panel's settled height between the stops, carried by the same spring
  /// the sheet settles with.
  late final AnimationController _motion = AnimationController.unbounded(vsync: this);
  bool _placed = false;

  /// Where the finger has taken the panel's height while a drag is live.
  double _drag = 0;
  bool _dragging = false;

  /// How low a drag may take the panel: past the lowest stop there is still
  /// room to pull, which is how the pull into the portrait full screen reads
  /// as a distance (the reference's own 120 floor).
  static const double _dragFloor = 120;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _settle(double target) {
    final motion = DsTheme.of(context).motion;
    final spring = motion.moveSpringOrNull;
    if (spring == null) {
      _motion.value = target;
      return;
    }
    _motion.animateTo(target, duration: spring.settleDuration, curve: motion.moveCurve);
  }

  /// The stop the panel's height now sits nearest to: the chips row's lit one.
  RoomPanelStop _current(RoomPanelStops stops) {
    var best = RoomPanelStop.minimum;
    var bestGap = double.infinity;
    for (final stop in RoomPanelStop.values) {
      final gap = (RoomBottomPanel.stopOf(stops, stop) - _motion.value).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = stop;
      }
    }
    return best;
  }

  void _started() {
    _motion.stop();
    _dragging = true;
    _drag = _motion.value;
  }

  /// Up to the highest stop and no further, since that stop's strip of free
  /// picture is the point of it; down to the drag floor, where the pull past
  /// the lowest stop is read on release.
  void _dragged(DragUpdateDetails details, RoomPanelStops stops) {
    if (!_dragging) return;
    _drag = clampDouble(_drag - details.delta.dy, _dragFloor, stops.greatest);
    _motion.value = _drag;
  }

  /// The finger left: far enough under the lowest stop — or a downward flick —
  /// the portrait full screen; anywhere else, the stop the release points at.
  void _released(DragEndDetails details, RoomPanelStops stops) {
    if (!_dragging) return;
    _dragging = false;
    // Downwards positive: the direction that shrinks the panel.
    final velocity = details.primaryVelocity ?? 0;
    if (widget.onPortraitFullscreen != null &&
        RoomBottomPanel.entersFullscreen(dismissed: stops.least - _drag, panel: stops.least, velocity: velocity)) {
      widget.onPortraitFullscreen!();
      return;
    }
    _settle(RoomBottomPanel.nearestStop(clampDouble(_drag, stops.least, stops.greatest), velocity, stops));
  }

  /// A drag the system took back settles where it stands.
  void _cancelled(RoomPanelStops stops) {
    if (!_dragging) return;
    _dragging = false;
    _settle(RoomBottomPanel.nearestStop(clampDouble(_drag, stops.least, stops.greatest), 0, stops));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (constraints.maxWidth.isFinite ? constraints.maxWidth * 2 : RoomBottomPanel.least * 3);
        final stops = RoomBottomPanel.stopsOf(area);
        if (!_placed) {
          _placed = true;
          // The reference opens the compact panel at its lowest stop: the
          // stream leads, the talk follows.
          _motion.value = stops.least;
        } else if (!_dragging && !_motion.isAnimating) {
          // A rotation or a window resize moved the stops under the panel; it
          // keeps the edge it left rather than hanging over black.
          final height = _motion.value;
          if (height > stops.greatest || height < stops.least) {
            _motion.value = clampDouble(height, stops.least, stops.greatest);
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: kPlayerStageColor,
                child: Center(
                  child: AspectRatio(aspectRatio: widget.ratio, child: widget.player),
                ),
              ),
            ),
            // The grip: the app's touch floor of a row holding the reference's
            // own bar, the one place a thumb takes the panel's height.
            GestureDetector(
              onVerticalDragStart: (_) => _started(),
              onVerticalDragUpdate: (details) => _dragged(details, stops),
              onVerticalDragEnd: (details) => _released(details, stops),
              onVerticalDragCancel: () => _cancelled(stops),
              child: SizedBox(
                height: RoomBottomPanel.handleHeight,
                child: Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _motion,
              builder: (context, _) => SizedBox(
                height: math.max(0, _motion.value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _RoomPanelInfo(),
                    Expanded(child: widget.chat),
                    _PanelStops(
                      current: _current(stops),
                      onPick: (stop) => _settle(RoomBottomPanel.stopOf(stops, stop)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The compact panel's facts row (the redesign's pinfo): the stream's title —
/// one press from the details — and, at the row's end, the two figures a
/// live room is asked about, the audience and the watched time. One line, so
/// the talk under it keeps the height: the identity lives in the bar above
/// and the figures' full set in the details, not here.
final class _RoomPanelInfo extends ConsumerWidget {
  const _RoomPanelInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    final caption = theme.typography.caption.copyWith(color: colors.textMuted);
    final title = detail?.content.title ?? '';
    final viewers = detail?.audience.onlineViewers ?? detail?.audience.totalViewers;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s6, DsSpace.s12, DsSpace.s6),
      decoration: BoxDecoration(
        border: BorderDirectional(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsPressable(
              semanticLabel: t.room.detailsHint,
              onPressed: title.isEmpty ? null : () => unawaited(showRoomDetails(context)),
              builder: (context, states, _) {
                final text = Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: states.contains(WidgetState.hovered) ? colors.accent : colors.text,
                  ),
                );
                // No facts yet, no tooltip to hover.
                return title.isEmpty ? text : DsTooltip(message: title, child: text);
              },
            ),
          ),
          if (detail != null)
            Text.rich(
              TextSpan(
                style: caption,
                children: [
                  if (viewers != null) ...[
                    TextSpan(
                      text: AudienceFormat.format(viewers),
                      style: theme.typography.numeric(caption).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' '),
                  ],
                  TextSpan(text: t.room.statViewers),
                  TextSpan(text: ' · ${t.room.statWatched} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _WatchedClock(
                      style: theme.typography.numeric(caption).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            const DsSkeleton(width: 120, height: 12),
        ],
      ),
    );
  }
}

/// The watched clock for the facts row, ticking once a second: the row
/// rebuilds on the room's own updates far less often than a counter moves.
final class _WatchedClock extends ConsumerStatefulWidget {
  const _WatchedClock({required this.style});

  final TextStyle style;

  @override
  ConsumerState<_WatchedClock> createState() => _WatchedClockState();
}

final class _WatchedClockState extends ConsumerState<_WatchedClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchStarted = ref.watch(roomProvider.select((room) => room.watchStartedAt));
    return Text(_roomClock(watchStarted), style: widget.style);
  }
}

/// The docks' chips (the reference's `.stops`): the three stops by name with
/// the live one lit, and the word about the pull past the lowest one — a
/// pointer's way to the heights a thumb reaches by dragging.
final class _PanelStops extends StatelessWidget {
  const _PanelStops({required this.current, required this.onPick});

  final RoomPanelStop current;
  final ValueChanged<RoomPanelStop> onPick;

  /// The stops' names, the reference's own: a floor in pixels, then the two
  /// fractions of the window.
  static const Map<RoomPanelStop, String> _labels = {
    RoomPanelStop.minimum: '250px',
    RoomPanelStop.middle: '44%',
    RoomPanelStop.maximum: '68%',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final caption = theme.typography.caption.copyWith(color: colors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: DsSpace.s6,
        runSpacing: DsSpace.s4,
        children: [
          Text(t.room.panelStops, style: caption),
          for (final entry in _labels.entries)
            DsPressable(
              semanticLabel: entry.value,
              onPressed: entry.key == current ? null : () => onPick(entry.key),
              builder: (context, states, _) {
                final on = entry.key == current;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                  decoration: BoxDecoration(
                    // The reference's own 8 px chip.
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: on ? colors.accent : colors.border),
                  ),
                  child: Text(
                    entry.value,
                    style: theme.typography.caption.copyWith(
                      color: on ? colors.accent : colors.textMuted,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          Text('· ${t.room.panelStopsHint}', style: caption),
        ],
      ),
    );
  }
}

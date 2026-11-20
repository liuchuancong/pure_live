part of 'room_page.dart';

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

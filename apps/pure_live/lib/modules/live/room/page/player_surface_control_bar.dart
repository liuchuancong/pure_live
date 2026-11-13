part of 'player_surface.dart';

/// The bar itself: the transport, the stream pickers, the danmaku cluster and
/// the presentation buttons — icons that say the word on hover, a button per
/// verb.
///
/// The room draws no timeline and no pace, live or replay alike: this page is
/// where a stream is watched as it happens, and a replay worth scrubbing
/// belongs to the vod page, whose bar carries the slider and the rate. What
/// used to sit above these buttons was a seek line that a live stream could
/// not follow and a replay room never asked this page for.
final class _ControlBar extends ConsumerStatefulWidget {
  const _ControlBar({
    required this.handle,
    required this.transport,
    required this.onWake,
    this.streamPickers,
    this.onDanmakuSettings,
    this.danmakuSettingsAnchor,
    this.autofocusPlay = false,
    this.canEnterPortraitFullscreen = false,
    this.portraitFullscreen = false,
    this.onPortraitFullscreen,
    this.onFullscreen,
    super.key,
  });

  final PlayerHandle handle;

  /// The latest transport snapshot, null until the first event.
  final PlayerTransportState? transport;

  /// Resets the bar's auto-hide timer after an interaction.
  final VoidCallback onWake;

  /// The stream's own catalogues (quality, line), placed beside the
  /// transport where a viewer looks for them.
  ///
  /// Built with the bar's own width, because that is the box the result has
  /// to fit: a narrow stage inside a wide window — an open chat panel, say —
  /// leaves little room for words beside the glyph, and words chosen from the
  /// window's size overflowed the strip. `labelled` says whether the current
  /// choice's words fit beside the glyph.
  final Widget Function({required bool labelled, required bool fitOnly})? streamPickers;

  /// Opens the video-area danmaku settings panel; null leaves the gear inert.
  final VoidCallback? onDanmakuSettings;

  /// The gear's box, for the panel host that hangs the settings above it.
  final GlobalKey? danmakuSettingsAnchor;

  /// Focuses the play button when it first builds (the TV room's start).
  final bool autofocusPlay;

  /// Whether a portrait stream offers the entry button.
  final bool canEnterPortraitFullscreen;

  /// Whether the portrait full-screen surface is already showing.
  final bool portraitFullscreen;

  /// Enters portrait full screen.
  final VoidCallback? onPortraitFullscreen;

  /// The page's shape-aware fullscreen toggle (a portrait stream answers
  /// with the portrait surface); null keeps the presentation's own toggle.
  final VoidCallback? onFullscreen;

  @override
  ConsumerState<_ControlBar> createState() => _ControlBarState();
}

final class _ControlBarState extends ConsumerState<_ControlBar> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    final presentation = ref.watch(roomPresentationProvider);
    final controller = ref.read(roomProvider.notifier);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final player = room.handle?.id;
    final playing = room.playback.playing;
    // The state echo of a mute switch rebuilds this bar, so the icon reads
    // fresh without its own stream.
    final tv = PlayerBarTier.tvOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        tv ? DsSpace.s16 : DsSpace.s12,
        tv ? DsSpace.s12 : DsSpace.s8,
        tv ? DsSpace.s16 : DsSpace.s12,
        tv ? DsSpace.s12 : DsSpace.s8,
      ),
      decoration: BoxDecoration(
        gradient: OnVideoColors.shade(edge: VerticalDirection.down, strong: OnVideoColors.scrimDeep),
      ),
      // Two width tiers, each a superset of the other: the desktop bar gains
      // the volume slider beside the window-fullscreen button at 720, the
      // strip's own measure; below 320 the danmaku cluster and the divider
      // give way, the picture's own catalogues being the cluster a viewer
      // reaches for when the picture looks wrong.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pip = presentation == PresentationMode.pip && presentationController.pipOwnsWindow;
          final wide = constraints.maxWidth >= 720;
          final crowded = constraints.maxWidth < 320;
          final play = PlayerBarButton(
            iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
            label: playing ? t.room.pause : t.room.play,
            autofocus: widget.autofocusPlay,
            onPressed: () {
              widget.onWake();
              unawaited(controller.togglePlayPause());
            },
          );
          final retry = PlayerBarButton(
            icon: DsIcons.refreshCw,
            label: t.common.retry,
            onPressed: () {
              widget.onWake();
              unawaited(controller.retry());
            },
          );
          // The mute toggle and its level: the bar's own pair, where the
          // wheel and the arrows have always reached. The slider rides only
          // where the bar has the room for it (the desktop widths); a narrow
          // strip keeps the toggle alone — the picture's vertical drag still
          // moves the level there. Both read the state record: mute is not
          // on the transport stream, so the record's write after a set —
          // here or on any other surface — is what turns the glyph.
          final muted = room.muted;
          final muteButton = !pip && player != null
              ? PlayerBarButton(
                  icon: muted ? DsIcons.volumeOff : DsIcons.volume2,
                  label: muted ? t.room.unmute : t.room.mute,
                  onPressed: () {
                    widget.onWake();
                    unawaited(controller.setMuted(value: !muted));
                  },
                )
              : null;
          final volumeSlider = !pip && player != null && wide
              ? SizedBox(
                  width: 72,
                  child: DsSlider(
                    value: (room.volume * 100).clamp(0.0, 100.0),
                    max: 100,
                    onChanged: (value) {
                      widget.onWake();
                      unawaited(controller.setVolume(value / 100));
                    },
                    semanticLabel: t.room.volume,
                  ),
                )
              : null;
          // The danmaku cluster: the switch and the nut-badged glyph that
          // opens its settings, the pair the viewer tunes without leaving the
          // bar.
          final danmaku = !crowded && !pip
              ? _DanmakuBarCluster(
                  onWake: widget.onWake,
                  onSettings: widget.onDanmakuSettings,
                  settingsAnchor: widget.danmakuSettingsAnchor,
                )
              : null;
          // The bar sits beside the chat column, so its own width can be much
          // smaller than the window. The window decides whether all catalogues
          // fit; the bar must not silently downgrade to fit-only.
          final compactPickers = MediaQuery.sizeOf(context).width < 600;
          final pickers = !pip ? widget.streamPickers?.call(labelled: true, fitOnly: compactPickers) : null;
          final windowButton = !pip && player != null && wide
              ? PlayerBarButton(
                  // The window's own spread: out where the mode is off, in
                  // where it is on — the two chevrons, not the arrows.
                  icon: presentation == PresentationMode.windowFullscreen
                      ? DsIcons.chevronsRightLeft
                      : DsIcons.chevronsLeftRight,
                  label: presentation == PresentationMode.windowFullscreen
                      ? t.room.windowFullscreenOff
                      : t.room.windowFullscreenOn,
                  selected: presentation == PresentationMode.windowFullscreen,
                  onPressed: () {
                    widget.onWake();
                    unawaited(presentationController.toggleWindowFullscreen(player));
                  },
                )
              : null;
          final fullscreenButton = !pip && player != null
              ? PlayerBarButton(
                  icon: presentation == PresentationMode.fullscreen ? DsIcons.minimize : DsIcons.maximize,
                  label: presentation == PresentationMode.fullscreen ? t.room.fullscreenOff : t.room.fullscreenOn,
                  selected: presentation == PresentationMode.fullscreen,
                  onPressed: () {
                    widget.onWake();
                    if (widget.onFullscreen case final onFullscreen?) {
                      onFullscreen();
                      return;
                    }
                    unawaited(presentationController.toggleFullscreen(player));
                  },
                )
              : null;
          return Row(
            spacing: tv ? DsSpace.s8 : DsSpace.s4,
            children: [
              play,
              retry,
              ?muteButton,
              ?volumeSlider,
              ?danmaku,
              if (pickers != null)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: pickers),
                  ),
                )
              else
                const Spacer(),
              if (!crowded) const _BarDivider(),
              ?windowButton,
              ?fullscreenButton,
            ],
          );
        },
      ),
    );
  }
}

/// The bar's danmaku pair (the reference's switch and gear): the on/off
/// glyphs the station draws — the off one wearing the barred circle — and the
/// nut-badged glyph that opens its settings. A viewer toggles the lines and
/// tunes them without leaving the bar.
final class _DanmakuBarCluster extends ConsumerWidget {
  const _DanmakuBarCluster({required this.onWake, this.onSettings, this.settingsAnchor});

  /// Resets the bar's auto-hide timer after a press.
  final VoidCallback onWake;

  /// Opens the video-area settings panel; null leaves the gear inert.
  final VoidCallback? onSettings;

  /// The gear's box, for the panel host that hangs the settings above it.
  final GlobalKey? settingsAnchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final side = PlayerBarTier.controlSize(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s4,
      children: [
        DsTooltip(
          message: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
          child: DsPressable(
            semanticLabel: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
            onPressed: () {
              onWake();
              unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !settings.danmakuVisible));
            },
            builder: (context, states, _) {
              final on = settings.danmakuVisible;
              final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
              // The pair the reference serves: the off glyph wears the barred
              // circle, the on glyph the check — the badge says which, so both
              // take the bar's ink and the off one only steps back a shade.
              return Container(
                width: side,
                height: side,
                alignment: Alignment.center,
                decoration: DsBoxDecoration(
                  color: lit ? _onVideoHover : null,
                  borderRadius: DsTheme.of(context).radii.controlCorners(null, side),
                ),
                child: SvgPicture.asset(
                  on ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
                  width: side * .5,
                  height: side * .5,
                  colorFilter: ColorFilter.mode(on ? _onVideo : _onVideoMuted, BlendMode.srcIn),
                ),
              );
            },
          ),
        ),
        PlayerBarButton(
          key: settingsAnchor,
          iconAsset: 'assets/icons/danmaku-settings.svg',
          label: t.settings.navDanmaku,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

/// A hair divider between the fitted bar's clusters: the transport on one
/// side, the stream's own menus on the other.
final class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) {
    final tv = PlayerBarTier.tvOf(context);
    return Container(
      width: 1,
      height: tv ? 20 : 16,
      margin: EdgeInsets.symmetric(horizontal: tv ? DsSpace.s8 : DsSpace.s4),
      color: OnVideoColors.track,
    );
  }
}

/// The strip the live room keeps while its bar is hidden: the same hit height
/// as the shared idle line, with nothing drawn. Hovering or tapping it wakes
/// the controls; a live picture has no progress to show in the meantime.
final class _IdleWakeStrip extends StatelessWidget {
  const _IdleWakeStrip({required this.onWake});

  /// Wakes the bar this strip belongs to.
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => onWake(),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onWake,
      child: const SizedBox(height: 14, width: double.infinity),
    ),
  );
}

/// Whether an upward swipe of [upward] pixels that ended at [velocity] (upwards
/// negative) restores the page's layout from the portrait full screen (the
/// reference's `swipeRestoresPanel`): 64 px of travel, or a flick of 850 px/s
/// once 24 of them are behind it.
bool _swipeRestoresPanel({required double upward, required double velocity}) =>
    upward >= 64 || (velocity <= -850 && upward >= 24);

/// The portrait full screen's bottom bar, or the strip that wakes it, taking
/// the upward swipe back to the page's panel as well (the reference's
/// `_SwipeUpRegion`).
///
/// Both stand over the picture's gesture layer and keep the pointer from it,
/// yet they are the floor of the band the swipe starts from. The buttons under
/// it keep their taps: a drag only wins once the finger moves. Without
/// [onRestore] it listens for nothing, and the tree keeps its shape either way.
final class _RestoreSwipe extends StatefulWidget {
  const _RestoreSwipe({required this.onRestore, required this.child});

  /// Restores the page's layout; null where the swipe means nothing.
  final VoidCallback? onRestore;

  /// The bar or the strip.
  final Widget child;

  @override
  State<_RestoreSwipe> createState() => _RestoreSwipeState();
}

final class _RestoreSwipeState extends State<_RestoreSwipe> {
  /// The swipe's travel up the bar, never below zero.
  double _upward = 0;

  @override
  Widget build(BuildContext context) {
    final restore = widget.onRestore;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: restore == null ? null : (_) => _upward = 0,
      onVerticalDragUpdate: restore == null
          ? null
          : (details) => _upward = (_upward - details.delta.dy).clamp(0.0, double.infinity),
      onVerticalDragEnd: restore == null
          ? null
          : (details) {
              final upward = _upward;
              _upward = 0;
              if (_swipeRestoresPanel(upward: upward, velocity: details.primaryVelocity ?? 0)) restore();
            },
      onVerticalDragCancel: restore == null ? null : () => _upward = 0,
      child: widget.child,
    );
  }
}

/// The compact danmaku settings: display area, font size, opacity and speed.
/// Everything else waits behind [onAdvanced].
final class _DanmakuSettingsControls extends ConsumerWidget {
  const _DanmakuSettingsControls({required this.onWake, required this.onAdvanced});

  final VoidCallback onWake;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final labelStyle = theme.typography.caption.copyWith(color: _onVideoMuted);
    final valueStyle = theme.typography.caption.copyWith(color: _onVideo);
    final sliderStyle = DsSliderStyle(
      trackColor: OnVideoColors.inkHover,
      fillColor: colors.accent,
      thumbColor: colors.accent,
      tickColor: OnVideoColors.inkMuted,
      tickFilledColor: colors.accent,
    );
    Widget sliderRow({
      required String label,
      required String value,
      required double current,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      int? divisions,
      String Function(double)? formatter,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s4,
      children: [
        Row(
          children: [
            Text(label, style: labelStyle),
            const Spacer(),
            Text(value, style: valueStyle),
          ],
        ),
        DsSlider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: label,
          semanticFormatter: formatter,
          style: sliderStyle,
          onChanged: (next) {
            onWake();
            onChanged(next);
          },
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        sliderRow(
          label: t.settings.styleArea,
          value: '${(style.area * 100).round()}%',
          current: style.area,
          min: DanmakuStyleRange.areaMin,
          max: DanmakuStyleRange.areaMax,
          divisions: DanmakuStyleRange.areaDivisions,
          onChanged: (value) => unawaited(controller.setArea(value)),
        ),
        sliderRow(
          label: t.settings.styleFontSize,
          value: '${style.fontSize.toStringAsFixed(0)} px',
          current: style.fontSize,
          min: DanmakuStyleRange.fontSizeMin,
          max: DanmakuStyleRange.fontSizeMax,
          onChanged: (value) => unawaited(controller.setFontSize(value)),
        ),
        sliderRow(
          label: t.settings.styleOpacity,
          value: '${(style.opacity * 100).round()}%',
          current: style.opacity,
          min: DanmakuStyleRange.opacityMin,
          max: DanmakuStyleRange.opacityMax,
          onChanged: (value) => unawaited(controller.setOpacity(value)),
        ),
        sliderRow(
          label: t.settings.styleSpeed,
          value: '${style.baseSpeed.round()} px/s',
          current: style.baseSpeed,
          min: DanmakuStyleRange.speedMin,
          max: DanmakuStyleRange.speedMax,
          onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
        ),
        Container(height: 1, color: OnVideoColors.inkHover),
        DsPressable(
          semanticLabel: t.settings.styleAdvanced,
          onPressed: onAdvanced,
          builder: (context, states, _) => Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
            decoration: DsBoxDecoration(
              color: states.contains(WidgetState.hovered) ? OnVideoColors.inkHover : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                const DsIcon(DsIcons.settings2, size: 15, color: _onVideoMuted),
                Text(t.settings.styleAdvanced, style: theme.typography.caption.copyWith(color: _onVideo)),
                const Spacer(),
                const DsIcon(DsIcons.chevronRight, size: 14, color: _onVideoMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

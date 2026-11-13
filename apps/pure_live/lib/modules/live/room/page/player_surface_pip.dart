part of 'player_surface.dart';

final class _PresentationCluster extends ConsumerWidget {
  const _PresentationCluster({required this.room, required this.onWake, required this.narrow});

  final RoomState room;

  /// Resets the bars' auto-hide timer after a press.
  final VoidCallback onWake;

  /// Whether the strip has room for the verbs; below it they live in the menu.
  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final detail = room.room;
    final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
    final presentation = ref.watch(roomPresentationProvider);
    final pipAvailable = room.handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    final task = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, detail);
    final recording = task?.state == RecordingTaskState.recording;
    // A take that is not writing is still a fact about this room: a subscription
    // armed and waiting for its streamer, a capture whose segments are still
    // being joined, and a take that ended in failure. None of them had a word on
    // the bar, which showed the plain record button instead — the strip that
    // reads as "nothing is happening here" while a take is queued or unfinished.
    final pending = recording ? null : task;
    final joining = pending?.postProcessing ?? false;
    // The word the strip carries for a take that is not writing — the same
    // mapping the recorder centre shows, so the two surfaces cannot call
    // one task different things. A joining take says how far the join got,
    // the way the reference's badge does (合成中 45%): a join runs minutes,
    // the strip has no progress bar, and a word alone cannot answer "is it
    // moving or stuck".
    final pendingDisplay = pending == null ? null : RecordingDisplayState.of(pending);
    final pendingWord = pendingDisplay == null || !pendingDisplay.showsOnBar
        ? null
        : pendingDisplay.word(
            context,
            joinPercent: pendingDisplay == RecordingDisplayState.joining && pending!.postProcessingProgress >= 0
                ? (pending.postProcessingProgress.clamp(0.0, 1.0) * 100).round()
                : null,
          );
    // What the strip has room for. A narrow tier with nothing running shows no
    // cluster at all — an empty glass pill would be a hole in the strip — and a
    // word is wider than the icon it replaces, so it waits for room.
    final showRecord = !narrow && (recording || line != null || pendingWord != null);
    final showPip = pipAvailable;
    // Casting needs a stream to cast at, and the narrow tier has no room for
    // the verb: the line is what the picker is aimed at.
    final castLine = narrow ? null : line;
    if (!showRecord && !showPip && castLine == null) return const SizedBox.shrink();
    final tv = PlayerBarTier.tvOf(context);
    return PlayerGlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tv ? DsSpace.s8 : DsSpace.s4,
        children: [
          if (recording || pendingWord != null)
            RecordingIndicator(
              startedAt: recording ? task?.startedAt : null,
              showTimer: !narrow,
              // The take's size beside its clock: a growing number is the only
              // proof that a capture is still writing, and the engine's own
              // progress write is what makes it move once a second.
              word: pendingWord,
              // The TV tier grows every control on the bar; the indicator is
              // one of them, or it reads as a smudge from the sofa (§10.5).
              tv: tv,
              label: recording ? t.room.stopRecording : t.room.record,
              // A joining take has nothing to press: starting again now would
              // answer a question the viewer did not ask.
              onStop: joining
                  ? null
                  : () {
                      onWake();
                      unawaited(toggleRoomRecording(context, ref));
                    },
            )
          else if (showRecord)
            PlayerBarButton(
              icon: DsIcons.disc,
              label: t.room.record,
              onPressed: () {
                onWake();
                unawaited(toggleRoomRecording(context, ref));
              },
            ),
          if (showPip)
            PlayerBarButton(
              iconAsset: presentation == PresentationMode.pip ? 'assets/icons/pip-exit.svg' : 'assets/icons/pip.svg',
              label: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
              selected: presentation == PresentationMode.pip,
              onPressed: () {
                onWake();
                unawaited(toggleRoomPip(context, ref));
              },
            ),
          if (castLine != null)
            PlayerBarButton(
              icon: DsIcons.cast,
              label: t.room.cast,
              onPressed: () {
                onWake();
                unawaited(showCastDialog(context, line: castLine, title: detail?.content.title));
              },
            ),
        ],
      ),
    );
  }
}

/// The compact window's title strip (the redesign's piptitle): who is on and
/// what they are streaming, in one dark pill at the picture's top-left. A grab
/// on it moves the window — it sits over the picture, so it takes the drag
/// the picture itself would have answered — and a double press restores.
final class _PipTitle extends ConsumerWidget {
  const _PipTitle({required this.room, required this.onRestore});

  final RoomState room;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final detail = room.room;
    final anchor = (detail?.anchor?.name ?? '').trim();
    final name = anchor.isEmpty ? (detail?.content.title ?? '') : anchor;
    final title = detail == null || detail.content.title == name ? '' : detail.content.title;
    final clipped = title.isEmpty ? null : (title.length > 12 ? '${title.substring(0, 12)}…' : title);
    final words = [if (name.isNotEmpty) name, ?clipped].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        final window = ref.read(windowsPipWindowProvider);
        if (window != null) unawaited(window.startDragging());
      },
      onDoubleTap: onRestore,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s3, DsSpace.s8, DsSpace.s3),
        decoration: BoxDecoration(color: OnVideoColors.scrimDeep, borderRadius: BorderRadius.circular(DsRadii.pill)),
        child: Text(
          words,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
        ),
      ),
    );
  }
}

/// The compact window's strip.
///
/// The redesign's pipbar: one glass row carrying every room verb as an icon —
/// play, mute, the replay's pace, the flying danmaku, the capture and its
/// stop, the sleep timer, the background listening, the next room, the
/// stream's figures, the lock — and the window's own two at the far end. The
/// window verbs (quality, line, picture shape, the danmaku's deeper settings)
/// stay on the page's bars: a picker raised inside a strip this small would
/// cover the picture it adjusts (the ledger's F deviation). A locked strip
/// carries only its unlock, and it never hides — without it the window would
/// have no way back.
final class _PipBar extends ConsumerStatefulWidget {
  const _PipBar({
    required this.room,
    required this.locked,
    required this.onToggleLock,
    required this.onRestore,
    required this.onClose,
  });

  final RoomState room;

  /// The strip's own lock: only the unlock remains while it holds.
  final bool locked;
  final VoidCallback onToggleLock;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  ConsumerState<_PipBar> createState() => _PipBarState();
}

final class _PipBarState extends ConsumerState<_PipBar> {
  /// The replay's asked pace, in the control bar chip's own words: read back
  /// from the handle until this strip asks for another, and never argued with
  /// by a second surface.
  double? _rate;

  /// The strip's own mute word; null follows the controller, so a surface
  /// elsewhere muting the room still reads here.
  bool? _muted;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final room = widget.room;
    final controller = ref.read(roomProvider.notifier);
    final muted = _muted ?? controller.muted;
    final playing = room.playback.playing;
    final detail = room.room;
    final capture = roomRecordingTaskOf(ref.watch(recordingTasksProvider).tasks, detail);
    final recording = capture?.state == RecordingTaskState.recording;
    final canCapture = room.handle?.canCaptureScreenshot ?? false;
    final dmVisible = ref.watch(playbackSettingsProvider.select((settings) => settings.miniDanmakuVisible));
    final audioOnly = room.audioOnly;
    final replay = detail?.broadcast.isRecord ?? false;
    final fit = ref.watch(playbackSettingsProvider.select((settings) => settings.fit));
    final handle = room.handle;
    final rate = _rate ?? handle?.rate ?? 1.0;

    Widget button({
      required String label,
      required VoidCallback? onPressed,
      DsIconData? icon,
      String? iconAsset,
      bool lit = false,
      bool danger = false,
      bool dim = false,
    }) {
      return _PipButton(
        icon: icon,
        iconAsset: iconAsset,
        label: label,
        onPressed: onPressed,
        lit: lit,
        danger: danger,
        dim: dim,
      );
    }

    // Locked, the strip is its unlock: the lock's whole word is that the
    // picture is not to be adjusted, and a row of adjusters under it would
    // offer exactly that.
    final children = widget.locked
        ? [button(icon: DsIcons.unlock, label: t.room.unlockControls, onPressed: widget.onToggleLock, lit: true)]
        : [
            button(
              iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
              label: playing ? t.room.pause : t.room.play,
              onPressed: () => unawaited(controller.togglePlayPause()),
            ),
            button(
              icon: muted ? DsIcons.volumeOff : DsIcons.volume2,
              label: muted ? t.room.unmute : t.room.mute,
              onPressed: () {
                final next = !muted;
                setState(() => _muted = next);
                unawaited(controller.setMuted(value: next));
              },
            ),
            // The stream's menus, raised in this window: the page's ask
            // channel points at the main window, so the small window keeps
            // its own catalogue (the ledger's F deviation, answered).
            if (room.qualities.isNotEmpty)
              _PipMenuButton(
                icon: DsIcons.gauge,
                label: t.room.quality,
                items: [
                  for (final option in room.qualities)
                    DsMenuItem(
                      label: Text(option.displayLabel),
                      checked: option == (room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first)),
                      onPressed: () => unawaited(controller.selectQuality(option)),
                    ),
                ],
              ),
            if (room.lines.length > 1)
              _PipMenuButton(
                icon: DsIcons.route,
                label: t.room.lineLabel,
                items: [
                  for (final (index, option) in room.lines.indexed)
                    DsMenuItem(
                      label: Text(_lineShortLabel(t, option, index)),
                      checked: index == room.lineIndex,
                      onPressed: () => unawaited(controller.selectLine(index)),
                    ),
                ],
              ),
            _PipMenuButton(
              icon: DsIcons.aspectRatio,
              label: t.settings.fit,
              items: [
                for (final option in PlaybackFit.values)
                  DsMenuItem(
                    label: Text(fitLabels(t)[option.index]),
                    checked: option == fit,
                    onPressed: () => unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option)),
                  ),
              ],
            ),
            // The replay's pace, the control bar chip's own cycle.
            if (replay && handle != null)
              _PipSpeedChip(
                rate: rate,
                label: t.common.previewSpeed,
                onPressed: () {
                  const rates = [1.0, 1.25, 1.5, 2.0];
                  final next = rates[(rates.indexOf(rate) + 1) % rates.length];
                  setState(() => _rate = next);
                  unawaited(handle.setRate(next).catchError((Object _) {}));
                },
              ),
            button(
              icon: DsIcons.messageCircle,
              label: dmVisible ? t.room.danmakuChip : t.room.danmakuChipOff,
              onPressed: () =>
                  unawaited(ref.read(playbackSettingsProvider.notifier).setMiniDanmakuVisible(value: !dmVisible)),
              dim: !dmVisible,
            ),
            button(
              icon: DsIcons.camera,
              label: t.room.screenshot,
              onPressed: canCapture ? () => unawaited(takeRoomScreenshot(context, ref, room.handle!)) : null,
            ),
            button(
              icon: DsIcons.disc,
              label: recording ? t.room.stopRecording : t.room.record,
              onPressed: () => unawaited(toggleRoomRecording(context, ref)),
              danger: recording,
            ),
            button(icon: DsIcons.moon, label: t.room.sleep, onPressed: () => unawaited(showRoomSleepTimer(context))),
            button(
              icon: DsIcons.headphones,
              label: audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
              onPressed: () => unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: !audioOnly)),
              lit: audioOnly,
            ),
            if (detail != null)
              button(
                icon: DsIcons.arrowLeftRight,
                label: t.room.switchRoom,
                onPressed: () => unawaited(showRoomSwitcher(context, current: detail)),
              ),
            button(
              icon: DsIcons.activity,
              label: t.room.stats,
              onPressed: () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
            ),
            button(icon: DsIcons.lock, label: t.room.lockControls, onPressed: widget.onToggleLock),
            button(icon: DsIcons.expand, label: t.room.pipOff, onPressed: widget.onRestore),
            button(icon: DsIcons.x, label: t.common.close, onPressed: widget.onClose),
          ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        // The reference's glass row: the pane's ink over the picture, with the
        // shade the other bottom rows wear.
        gradient: OnVideoColors.shade(edge: VerticalDirection.up),
        border: const Border(top: BorderSide(color: OnVideoColors.inkHover)),
      ),
      // A window narrower than the verbs scrolls the row, the reference's own
      // overflow-x: the window verbs stay reachable, the bar stays one line.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(spacing: DsSpace.s3, children: children),
      ),
    );
  }
}

/// One control on the compact window's strip: 28 px square, no tooltip (there
/// is no room for one in a small window), the label kept for screen readers.
final class _PipButton extends StatelessWidget {
  const _PipButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.lit = false,
    this.danger = false,
    this.dim = false,
  }) : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon].
  final String? iconAsset;
  final String label;
  final VoidCallback? onPressed;

  /// An on verb (background listening, the unlock): the accent ink.
  final bool lit;

  /// A writing capture: the danger ink.
  final bool danger;

  /// An off verb (the danmaku switch): the muted ink, dimmer than the rest.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final ink = !onPressedEnabled
        ? _onVideoSubtle
        : danger
        ? DsTheme.colorsOf(context).danger.text
        : lit
        ? DsTheme.colorsOf(context).accent
        : dim
        ? _onVideoSubtle
        : _onVideoMuted;
    // The pressable draws the focus ring itself, so a remote can reach what a
    // pointer used to tap; the visuals stay the 28 px square they were.
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, child) => SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: switch (iconAsset) {
            final String asset => SvgPicture.asset(
              asset,
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
            ),
            _ => DsIcon(icon!, size: 14, color: ink),
          },
        ),
      ),
    );
  }

  bool get onPressedEnabled => onPressed != null;
}

/// The compact strip's stream menu: a menu raised in the window the strip
/// draws in, over the same verbs the page's pickers keep. The trigger is the
/// strip's own square; the current choice wears the check.
final class _PipMenuButton extends StatelessWidget {
  const _PipMenuButton({required this.icon, required this.label, required this.items});

  final DsIconData icon;
  final String label;
  final List<DsMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return DsMenuAnchor(
      semanticLabel: label,
      items: items,
      builder: (context, controller, _) => _PipButton(icon: icon, label: label, onPressed: controller.toggle),
    );
  }
}

/// The replay's pace chip on the compact strip: one word cycling the rates,
/// the control bar's own verb in the bar's own ink.
final class _PipSpeedChip extends StatelessWidget {
  const _PipSpeedChip({required this.rate, required this.label, required this.onPressed});

  final double rate;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: '$label $rate×',
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
        alignment: Alignment.center,
        child: Text(
          '$rate×',
          style: theme.typography.caption.copyWith(
            color: rate == 1.0 ? _onVideoSubtle : _onVideo,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The capture task that belongs to [detail], or null.
///
/// The task store is the truth both the strip's indicator and the page menu's
/// row follow, so a capture started in an earlier visit or by the schedule
/// reads the same in every one of them.
RecordingTask? roomRecordingTaskOf(Iterable<RecordingTask> tasks, LiveRoom? detail) {
  if (detail == null) return null;
  final id = '${detail.ref.platform}:${detail.ref.roomId}';
  return tasks.where((task) => task.id == id).firstOrNull;
}

/// Starts or stops this room's capture and answers which happened.
Future<void> toggleRoomRecording(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final recording =
      roomRecordingTaskOf(ref.read(recordingTasksProvider).tasks, ref.read(roomProvider).room)?.state ==
      RecordingTaskState.recording;
  final failure = await ref.read(roomProvider.notifier).toggleRecording();
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: failure == null ? (recording ? t.room.recordStopped : t.room.recordStarted) : t.room.recordFailed,
    status: failure == null ? DsStatus.success : DsStatus.danger,
  );
}

/// Enters or leaves the small window. A phone's system window can refuse (no
/// on-screen player layer, a device that cannot present it): saying so beats a
/// button that did nothing.
Future<void> toggleRoomPip(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final player = ref.read(roomProvider).handle?.id;
  if (player == null) return;
  final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(player);
  if (accepted || !context.mounted) return;
  showDsToast(context: context, title: t.common.pipUnavailable);
}

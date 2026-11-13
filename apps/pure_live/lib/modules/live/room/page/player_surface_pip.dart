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

/// The compact window's play/pause: a glass disc in the picture's middle,
/// bigger than any bar button — the one verb a small window is watched for.
/// It rides the chrome's visibility: hover wakes it, idleness puts it away.
final class _PipCenterPlay extends ConsumerWidget {
  const _PipCenterPlay({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = room.playback.playing;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A small window's disc shrinks with it: a 64 px button in a 200 px
        // window is a billboard, not a control.
        final compact = constraints.maxWidth < 320;
        final side = compact ? 40.0 : 64.0;
        final glyph = compact ? 18.0 : 28.0;
        return PlayerGlassPill(
          child: DsPressable(
            semanticLabel: playing ? context.t.room.pause : context.t.room.play,
            onPressed: () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
            builder: (context, states, _) => Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: states.contains(WidgetState.hovered) ? _onVideoHover : null,
              ),
              child: Center(
                child: SvgPicture.asset(
                  playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
                  width: glyph,
                  height: glyph,
                  colorFilter: const ColorFilter.mode(OnVideoColors.foreground, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The compact window's transport: the window-fullscreen bar's own look at
/// the picture's bottom edge — the sound and the flying layer's switch, the
/// two verbs the watching hand reaches for, with the window's pin at the
/// right corner. The play/pause lives in the picture's middle, the capture
/// verbs in the top-right cluster, the way out at the top-left.
final class _PipTransportBar extends ConsumerWidget {
  const _PipTransportBar({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = this.room;
    final controller = ref.read(roomProvider.notifier);
    final muted = room.muted;
    final dmVisible = ref.watch(playbackSettingsProvider.select((settings) => settings.miniDanmakuVisible));
    final pinTop = ref.watch(playbackSettingsProvider.select((settings) => settings.windowsPipAlwaysOnTop));
    return LayoutBuilder(
      builder: (context, constraints) {
        // A small window drops the level: the slider's thumb is wider than
        // the verbs it sits between, and the mute pill still says sound.
        final wide = constraints.maxWidth >= 320;
        return Container(
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
          decoration: BoxDecoration(
            // The control bar's own shade: the pane's ink deepening to the edge.
            gradient: OnVideoColors.shade(edge: VerticalDirection.down, strong: OnVideoColors.scrimDeep),
          ),
          child: Row(
            spacing: DsSpace.s4,
            children: [
              PlayerGlassPill(
                child: PlayerBarButton(
                  icon: muted ? DsIcons.volumeOff : DsIcons.volume2,
                  label: muted ? t.room.unmute : t.room.mute,
                  onPressed: () => unawaited(controller.setMuted(value: !muted)),
                ),
              ),
              // The level, the control bar's own slider: the mute pill alone
              // names the sound without letting a small window's viewer trim it.
              if (wide && room.handle != null)
                SizedBox(
                  width: 88,
                  child: DsSlider(
                    value: (room.volume * 100).clamp(0.0, 100.0),
                    max: 100,
                    onChanged: (value) => unawaited(controller.setVolume(value / 100)),
                    semanticLabel: t.room.volume,
                  ),
                ),
              PlayerGlassPill(
                child: PlayerBarButton(
                  // The station's own danmaku glyphs, the control bar's pair —
                  // not a speech bubble.
                  iconAsset: dmVisible ? 'assets/icons/danmaku-on.svg' : 'assets/icons/danmaku-off.svg',
                  label: dmVisible ? t.room.danmakuChip : t.room.danmakuChipOff,
                  onPressed: () =>
                      unawaited(ref.read(playbackSettingsProvider.notifier).setMiniDanmakuVisible(value: !dmVisible)),
                ),
              ),
              const Spacer(),
              // The window's pin: live on the host, remembered for the next
              // entry.
              PlayerGlassPill(
                child: PlayerBarButton(
                  icon: pinTop ? DsIcons.pin : DsIcons.pinOff,
                  label: t.settings.windowsPipAlwaysOnTop,
                  selected: pinTop,
                  onPressed: () {
                    final next = !pinTop;
                    unawaited(ref.read(playbackSettingsProvider.notifier).setWindowsPipAlwaysOnTop(value: next));
                    unawaited(ref.read(desktopWindowHostProvider).setAlwaysOnTop(value: next));
                  },
                ),
              ),
            ],
          ),
        );
      },
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

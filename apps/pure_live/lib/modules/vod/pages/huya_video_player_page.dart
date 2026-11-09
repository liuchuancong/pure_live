import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart'
    show MediaPlayerView, PlayerConfig, PlayerHandle, PlayerHandlePlayback, PlayerKernel, PlayerTransportState;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';
import 'package:pure_live/modules/vod/controller/huya_video.dart';
import 'package:pure_live/modules/vod/controller/huya_video_playback.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice, vodQualityProvider;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart' show VodGestureKind, VodGestureTip, VodSeekBar;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoRow, vodDurationText;
import 'package:pure_live/shared/shared.dart';

/// One Huya video: the picture the station's own player would show, the
/// gestures a video is watched with, and beside it what the video is and what
/// the station puts next to it.
final class HuyaVideoPlayerPage extends ConsumerStatefulWidget {
  /// The page for [id].
  const HuyaVideoPlayerPage({required this.id, super.key});

  /// The station's video id.
  final String id;

  @override
  ConsumerState<HuyaVideoPlayerPage> createState() => _HuyaVideoPlayerPageState();
}

final class _HuyaVideoPlayerPageState extends ConsumerState<HuyaVideoPlayerPage> {
  PlayerHandle? _handle;
  PlayerKernel? _kernel;
  HuyaVideoPlaybackController? _controller;
  bool _disposed = false;
  bool _startFailed = false;

  /// What the last gesture did, in the chip over the picture.
  VodGestureKind? _tipKind;
  String _tipValue = '';
  String? _tipNote;
  Timer? _tipTimer;

  /// The volume and position a gesture started from, so it moves from where
  /// the viewer was.
  double _volumeFrom = 1;
  Duration _scrubFrom = Duration.zero;
  double _scrubShare = 0;
  bool _scrubbing = false;

  static final _Idle _idle = _Idle();

  @override
  void initState() {
    super.initState();
    _kernel = ref.read(playerKernelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  /// Attaches the kernel's handle, builds the video's controller over it and
  /// opens where the viewer last stopped.
  Future<void> _start() async {
    final kernel = _kernel;
    if (kernel == null || _disposed) return;
    setState(() => _startFailed = false);
    try {
      final detail = await ref.read(huyaVideoDetailProvider(widget.id).future);
      if (_disposed) return;
      final handle = await kernel.create(
        config: const PlayerConfig(name: 'huya'),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
      if (_disposed) {
        silencePlayer(handle);
        unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      _controller = HuyaVideoPlaybackController(
        api: ref.read(huyaVideoApiProvider),
        session: handle,
        detail: detail,
        progress: ArchiveProgress(),
        maxHeight: _maxHeight(ref.read(vodQualityProvider)),
      );
      setState(() {});
      await _controller!.open(widget.id);
    } on Object {
      if (!_disposed) setState(() => _startFailed = true);
    }
  }

  void _retry() {
    ref.invalidate(huyaVideoDetailProvider(widget.id));
    unawaited(_start());
  }

  @override
  void dispose() {
    _disposed = true;
    _tipTimer?.cancel();
    final controller = _controller;
    final handle = _handle;
    final kernel = _kernel;
    var retirement = Future<void>.value();
    if (controller != null) {
      controller.dispose();
      retirement = controller.retirement;
    }
    if (handle != null && kernel != null) {
      silencePlayer(handle);
      retirement = Future.wait<void>([retirement, kernel.release(handle.id)]).then((_) {});
    }
    unawaited(retirement);
    super.dispose();
  }

  /// Shows [kind]'s answer over the picture for a moment.
  void _tip(VodGestureKind kind, String value, {String? note}) {
    _tipTimer?.cancel();
    setState(() {
      _tipKind = kind;
      _tipValue = value;
      _tipNote = note;
    });
    _tipTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _tipKind = null);
    });
  }

  /// Shows an answer that lasts until the gesture lets go.
  void _holdTip(VodGestureKind kind, String value, {String? note}) {
    _tipTimer?.cancel();
    setState(() {
      _tipKind = kind;
      _tipValue = value;
      _tipNote = note;
    });
  }

  void _clearTip() {
    _tipTimer?.cancel();
    if (_tipKind != null) setState(() => _tipKind = null);
  }

  /// A related pick replaces the picture rather than stacking a second
  /// decoder over it.
  void _openRelated(String id) {
    if (id.isEmpty || id == widget.id) return;
    context.pushReplacement('/huya/$id');
  }

  Future<void> _toggle() async {
    await _controller?.togglePlayPause();
  }

  Future<void> _step(int seconds) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.position + Duration(seconds: seconds);
    await controller.seek(target);
    _tip(
      seconds < 0 ? VodGestureKind.seekBack : VodGestureKind.seekForward,
      vodDurationText(target.isNegative ? Duration.zero : target),
      note: seconds > 0 ? '+$seconds' : '$seconds',
    );
  }

  void _onDoubleTap(VodTapSide side) {
    switch (side) {
      case VodTapSide.left:
        unawaited(_step(-10));
      case VodTapSide.right:
        unawaited(_step(10));
      case VodTapSide.middle:
        unawaited(_toggle());
    }
  }

  /// A horizontal drag walks the part: a full sweep is the whole length.
  void _onScrub(double delta, double width) {
    final controller = _controller;
    if (controller == null || width <= 0) return;
    if (!_scrubbing) {
      _scrubbing = true;
      _scrubFrom = controller.position;
      _scrubShare = 0;
    }
    _scrubShare += delta / width;
    final target = _scrubFrom + controller.duration * _scrubShare;
    _holdTip(
      VodGestureKind.seek,
      vodDurationText(target.isNegative ? Duration.zero : target),
      note: '${(_scrubShare * 100).round()}%',
    );
  }

  void _onScrubEnd(bool committed) {
    final controller = _controller;
    if (_scrubbing && committed && controller != null) {
      final target = _scrubFrom + controller.duration * _scrubShare;
      unawaited(controller.seek(target.isNegative ? Duration.zero : target));
    }
    _scrubbing = false;
    _clearTip();
  }

  /// A vertical drag on the picture owns the sound: a desktop has no display
  /// brightness to write on this half.
  void _onAdjustStart(double share) {
    _volumeFrom = _handle?.playbackStream.value.volume ?? 1;
  }

  void _onAdjust(double delta) {
    final handle = _handle;
    if (handle == null) return;
    final next = (_volumeFrom - delta / 240).clamp(0.0, 1.0);
    _volumeFrom = next;
    unawaited(handle.setVolume(next));
    _holdTip(VodGestureKind.volume, '${(next * 100).round()}%');
  }

  void _onWheel(double delta) {
    final handle = _handle;
    if (handle == null) return;
    final next = (handle.playbackStream.value.volume - delta.sign * 0.05).clamp(0.0, 1.0);
    unawaited(handle.setVolume(next));
    _tip(VodGestureKind.volume, '${(next * 100).round()}%');
  }

  /// A hold runs the picture faster until the finger lifts.
  void _onHold(bool down) {
    final handle = _handle;
    final controller = _controller;
    if (handle == null || controller == null) return;
    if (down) {
      unawaited(handle.setRate(3));
      _holdTip(VodGestureKind.speed, '3.0x');
    } else {
      unawaited(handle.setRate(controller.rate));
      _clearTip();
    }
  }

  void _openUploader(String uid) {
    if (uid.isEmpty) return;
    unawaited(context.push('/huya/u/$uid'));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(huyaVideoDetailProvider(widget.id));
    final failed = _startFailed || (detail.hasError && _controller == null);
    final video = detail.value?.video;
    return PageSurface(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: video?.title ?? context.t.vod.huya),
            Expanded(
              child: failed ? _Failure(error: detail.error, onRetry: _retry) : _body(context, detail.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, HuyaVideoDetail? detail) {
    final related = ref.watch(huyaRelatedProvider(widget.id));
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final radius = BorderRadius.circular(DsTheme.of(context).radii.card);
    final video = detail?.video;
    final info = _Info(video: video, detail: detail, onUploader: _openUploader);
    final rail = _Related(
      videos: related.value ?? const <HuyaVideo>[],
      onOpen: _openRelated,
      loading: related.isLoading,
    );
    if (!wide) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(borderRadius: radius, child: _stage(context)),
            ),
            _bar(context),
            info,
            rail,
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(borderRadius: radius, child: _stage(context)),
                    ),
                  ),
                ),
                _bar(context),
              ],
            ),
          ),
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: DsSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s20,
                children: [info, rail],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The picture and its overlays: a dark stage while the handle arrives, a
  /// spinner while the walk opens, the gesture's own answer, and the failure
  /// with its way back in.
  Widget _stage(BuildContext context) {
    final t = context.t;
    final controller = _controller;
    final handle = _handle;
    return ListenableBuilder(
      listenable: controller ?? _idle,
      builder: (context, _) {
        final failed = _startFailed || controller?.error != null;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            if (handle != null) MediaPlayerView(handle: handle),
            Positioned.fill(
              child: VodPictureGestures(
                enabled: controller != null,
                onTap: () => unawaited(_toggle()),
                onDoubleTap: _onDoubleTap,
                onScrub: _onScrub,
                onScrubEnd: _onScrubEnd,
                onAdjustStart: _onAdjustStart,
                onAdjust: _onAdjust,
                onWheel: _onWheel,
                onHold: _onHold,
                child: const SizedBox.expand(),
              ),
            ),
            if (_tipKind case final kind?) VodGestureTip(kind: kind, value: _tipValue, note: _tipNote),
            if (controller != null && controller.busy)
              const Center(child: DsSpinner())
            else if (failed)
              Center(
                child: DsAlert(
                  status: DsStatus.danger,
                  title: Text(t.room.replayFailed),
                  description: controller?.error == null ? null : Text('${controller?.error}'),
                  action: DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () {
                      final current = controller;
                      if (current != null) unawaited(current.open(widget.id));
                    },
                    child: Text(t.common.retry),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The bar under the picture: play, the seek line, the clock, the
  /// renditions and the speed — the same controls the archive player wears.
  Widget _bar(BuildContext context) {
    final t = context.t;
    final controller = _controller;
    final handle = _handle;
    if (controller == null || handle == null) return const SizedBox(height: 56);
    final tv = PlayerBarTier.tvOf(context);
    final menuSize = tv ? DsSize.lg : DsSize.sm;
    return StreamBuilder<PlayerTransportState>(
      stream: handle.playbackStream,
      builder: (context, snapshot) {
        final transport = snapshot.data;
        final playing = transport?.command.isPlaying ?? false;
        final position = transport?.position ?? Duration.zero;
        final total = controller.duration > Duration.zero ? controller.duration : Duration.zero;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s4,
          children: [
            VodSeekBar(
              position: position,
              duration: total,
              coverUrl: controller.video.cover.isEmpty ? null : controller.video.cover,
              onSeek: (seconds) => unawaited(controller.seek(Duration(milliseconds: (seconds * 1000).round()))),
            ),
            Row(
              spacing: DsSpace.s12,
              children: [
                PlayerBarButton(
                  icon: playing ? DsIcons.pause : DsIcons.play,
                  label: playing ? t.room.pause : t.room.play,
                  autofocus: tv,
                  onPressed: () => unawaited(controller.togglePlayPause()),
                ),
                Text(
                  '${vodDurationText(position)} / ${vodDurationText(total)}',
                  style: DsTheme.of(context).typography.numeric(DsTheme.of(context).typography.caption),
                ),
                const Spacer(),
                if (controller.qualities.length > 1)
                  DsMenuAnchor(
                    semanticLabel: t.vod.huyaQuality,
                    align: DsAlign.end,
                    items: [
                      for (final quality in controller.qualities)
                        DsMenuItem(
                          label: Text(quality.label),
                          onPressed: () => unawaited(controller.selectQuality(quality.id)),
                        ),
                    ],
                    builder: (context, menu, _) => DsButton(
                      variant: DsButtonVariant.secondary,
                      size: menuSize,
                      onPressed: menu.toggle,
                      child: Text(
                        controller.qualities.where((item) => item.id == controller.qualityId).firstOrNull?.label ??
                            t.vod.huyaQuality,
                      ),
                    ),
                  ),
                DsMenuAnchor(
                  semanticLabel: t.vod.huyaSpeed,
                  align: DsAlign.end,
                  items: [
                    for (final rate in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                      DsMenuItem(label: Text('${rate}x'), onPressed: () => unawaited(controller.setRate(rate))),
                  ],
                  builder: (context, menu, _) => DsButton(
                    variant: DsButtonVariant.secondary,
                    size: menuSize,
                    onPressed: menu.toggle,
                    child: Text('${controller.rate}x'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The video's own block: what it is, who posted it and what it is about.
final class _Info extends StatelessWidget {
  const _Info({required this.video, required this.detail, required this.onUploader});

  final HuyaVideo? video;
  final HuyaVideoDetail? detail;
  final ValueChanged<String> onUploader;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final video = this.video;
    if (video == null) return const SizedBox.shrink();
    final brief = detail?.video.brief ?? video.brief;
    final tags = detail?.tags ?? const <String>[];
    final lines = [
      if (video.playCount > 0) '${AudienceFormat.format(video.playCount)} ${t.vod.views}',
      if (video.publishedAt case final at?) _date(at),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Text(video.title, style: theme.typography.title.copyWith(color: colors.text)),
        Row(
          spacing: DsSpace.s8,
          children: [
            DsAvatar(
              initials: avatarInitials(video.uploaderName.isEmpty ? video.title : video.uploaderName),
              image: video.uploaderAvatar.isEmpty
                  ? null
                  : cachedImage(video.uploaderAvatar, policy: ImageCachePolicies.avatar),
              size: DsSize.md,
              semanticLabel: video.uploaderName,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s3,
                children: [
                  GestureDetector(
                    onTap: video.uploaderId.isEmpty ? null : () => onUploader(video.uploaderId),
                    child: Text(
                      video.uploaderName.isEmpty ? t.vod.huya : video.uploaderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(
                        color: video.uploaderId.isEmpty ? colors.text : colors.indicator,
                      ),
                    ),
                  ),
                  if (lines.isNotEmpty)
                    Text(
                      lines.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (brief.isNotEmpty)
          Text(
            brief,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(color: colors.textMuted),
          ),
        if (tags.isNotEmpty)
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s4,
            children: [
              for (final tag in tags) Text('#$tag', style: theme.typography.caption.copyWith(color: colors.textMuted)),
            ],
          ),
      ],
    );
  }

  static String _date(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
}

/// What the station puts beside the video: one row each, the same shape the
/// station's own rail wears.
final class _Related extends StatelessWidget {
  const _Related({required this.videos, required this.onOpen, required this.loading});

  final List<HuyaVideo> videos;
  final ValueChanged<String> onOpen;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Text(t.vod.huyaRelated, style: theme.typography.title.copyWith(color: colors.text)),
        if (videos.isEmpty && loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DsSpace.s16),
            child: Center(child: DsSpinner()),
          )
        else
          for (final video in videos) VodVideoRow(video: video.asVideo(), onOpen: () => onOpen(video.id)),
      ],
    );
  }
}

/// The start's failure: the read that never answered, with its own retry.
final class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.film),
        title: Text(t.vod.errorTitle),
        description: Text(error?.toString() ?? t.vod.noResultsDescription),
        actions: [DsButton(variant: DsButtonVariant.secondary, onPressed: onRetry, child: Text(t.common.retry))],
      ),
    );
  }
}

/// The starts' tallest rendition, from the module's one starting-quality
/// preference: the station's ladder speaks pixels where Bilibili speaks qn.
int _maxHeight(VodQualityChoice choice) => switch (choice) {
  VodQualityChoice.p720 => 720,
  VodQualityChoice.p1080 || VodQualityChoice.p1080Plus || VodQualityChoice.p1080P60 => 1080,
  VodQualityChoice.p4k || VodQualityChoice.pHdr || VodQualityChoice.pDolby => 2160,
  VodQualityChoice.p8k => 4320,
};

/// The stand-in listenable the stage builds with before the controller
/// exists: never notifies, so the first frame is a dark stage and nothing
/// more.
final class _Idle extends ChangeNotifier {
  new();
}

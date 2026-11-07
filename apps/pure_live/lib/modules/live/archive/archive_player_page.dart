import 'dart:async' show Future, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_vod/live_vod.dart' show SoopArchivePart;
import 'package:media_core/media_core.dart'
    show MediaPlayerView, PlayerConfig, PlayerHandle, PlayerKernel, PlayerTransportState;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart' show accountsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_navigation.dart';
import 'package:pure_live/modules/live/archive/archive_playback.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';
import 'package:pure_live/modules/live/archive/huya_archive_controller.dart';
import 'package:pure_live/modules/live/archive/soop_archive_controller.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show vodDurationText;
import 'package:pure_live/shared/shared.dart';

/// A recording's player: the kernel's own handle over the archive
/// controller, the picture with its busy and failure overlays, and the
/// bar a recording needs — play, the seek the clock owns, the renditions
/// the part permits, the speed, and the parts when there is more than one.
final class ArchivePlayerPage extends ConsumerStatefulWidget {
  /// Builds the page for [request]; null renders the failure the walk
  /// without a seed deserves.
  const ArchivePlayerPage({this.request, super.key});

  /// The recording and the invoking room's callbacks.
  final ArchivePlayerRequest? request;

  @override
  ConsumerState<ArchivePlayerPage> createState() => _ArchivePlayerPageState();
}

final class _ArchivePlayerPageState extends ConsumerState<ArchivePlayerPage> {
  PlayerHandle? _handle;
  ArchivePlaybackController? _controller;
  bool _disposed = false;
  bool _startFailed = false;

  static final ChangeTracker _idle = ChangeTracker();

  /// The kernel, read once the state exists: the dispose path needs it and
  /// a provider read there throws.
  PlayerKernel? _kernel;

  @override
  void initState() {
    super.initState();
    _kernel = ref.read(playerKernelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  /// Attaches the kernel's handle, builds the recording's own controller
  /// over it, and opens where the viewer last walked.
  Future<void> _start() async {
    final request = widget.request;
    final kernel = _kernel;
    if (request == null || kernel == null || _disposed) return;
    try {
      final handle = await kernel.create(
        config: const PlayerConfig(name: 'archive'),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
      if (_disposed) {
        silencePlayer(handle);
        unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      final soop = request.soop;
      final huya = request.huya;
      if (soop != null) {
        _controller = SoopArchiveController(
          http: http,
          session: handle,
          recording: soop,
          progress: ArchiveProgress(),
          cookie: _soopCookie(),
          ownsSession: false,
        );
      } else if (huya != null) {
        _controller = HuyaArchiveController(http: http, session: handle, video: huya, progress: ArchiveProgress());
      }
      if (_controller == null) return;
      setState(() {});
      final recordingId = request.soop?.id ?? request.huya?.id;
      if (recordingId != null) await _controller!.open(recordingId);
    } on Object {
      if (!_disposed) setState(() => _startFailed = true);
    }
  }

  /// The viewer's SOOP login, the same credential the live site uses.
  String _soopCookie() {
    try {
      final credential = ref.read(accountsProvider).credentials[SiteIds.soop];
      if (credential == null) return '';
      return credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
    } on Object {
      return '';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    final handle = _handle;
    final kernel = _kernel;
    // The walk reports its own retirement: the progress save and the
    // native release together, because the invoking room may only resume
    // once the decoder is really gone.
    var retirement = Future<void>.value();
    if (controller != null) {
      controller.dispose();
      retirement = controller.retirement;
    }
    if (handle != null && kernel != null) {
      silencePlayer(handle);
      retirement = Future.wait<void>([retirement, kernel.release(handle.id)]).then((_) {});
    }
    widget.request?.arguments.onRetire?.call(retirement);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final t = context.t;
    if (request == null) {
      return PageSurface(
        child: Scaffold(
          body: Center(
            child: DsAlert(status: DsStatus.danger, title: Text(t.room.replayFailed)),
          ),
        ),
      );
    }
    final name = request.title;
    return PageSurface(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: name),
            Expanded(child: _stage(context)),
            if (_controller case final controller?) ...[
              _bar(context, controller),
              if (controller.segments.length > 1) _parts(context, controller),
            ],
          ],
        ),
      ),
    );
  }

  /// The picture and its overlays: a dark stage while the handle arrives,
  /// a spinner while the walk opens, and the failure with its way back in.
  Widget _stage(BuildContext context) {
    final controller = _controller;
    final handle = _handle;
    return ListenableBuilder(
      listenable: controller ?? _idle,
      builder: (context, _) {
        final failed = controller == null || _startFailed || controller.error != null;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            if (handle != null) MediaPlayerView(handle: handle),
            if (controller != null && controller.busy)
              const Center(child: DsSpinner())
            else if (failed)
              Center(
                child: DsAlert(
                  status: DsStatus.danger,
                  title: Text(context.t.room.replayFailed),
                  description: controller?.error == null ? null : Text('${controller?.error}'),
                  action: DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () {
                      final seed = widget.request;
                      final id = seed?.soop?.id ?? seed?.huya?.id;
                      if (id != null) unawaited(controller?.open(id));
                    },
                    child: Text(context.t.common.retry),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The recording's bar: play, the seek slider, the clock, and the two
  /// menus a recording owns — the part's renditions and the speed. The
  /// transport's stream drives the clock, the controller's notifies drive
  /// the rest.
  Widget _bar(BuildContext context, ArchivePlaybackController controller) {
    final t = context.t;
    return StreamBuilder<PlayerTransportState>(
      stream: _handle?.playbackStream,
      builder: (context, snapshot) {
        final transport = snapshot.data;
        final playing = transport?.command.isPlaying ?? false;
        final position = transport?.position ?? Duration.zero;
        final total = controller.duration > Duration.zero ? controller.duration : Duration.zero;
        return Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: playing ? t.room.pause : t.room.play,
                onPressed: () => unawaited(controller.togglePlayPause()),
                icon: DsIcon(playing ? DsIcons.pause : DsIcons.play, size: 16),
              ),
              Expanded(
                child: DsSlider(
                  value: position.inMilliseconds
                      .clamp(0, total.inMilliseconds <= 0 ? 0 : total.inMilliseconds)
                      .toDouble(),
                  max: (total.inMilliseconds <= 0 ? 1 : total.inMilliseconds).toDouble(),
                  onChanged: (value) => unawaited(controller.seek(Duration(milliseconds: value.round()))),
                ),
              ),
              Text(
                '${vodDurationText(position)} / ${vodDurationText(total)}',
                style: DsTheme.of(context).typography.numeric(DsTheme.of(context).typography.caption),
              ),
              if (controller.qualities.length > 1)
                DsMenuAnchor(
                  semanticLabel: t.room.replayQuality,
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
                    size: DsSize.sm,
                    onPressed: menu.toggle,
                    child: Text(
                      controller.qualities.where((item) => item.id == controller.qualityId).firstOrNull?.label ??
                          t.room.replayQuality,
                    ),
                  ),
                ),
              DsMenuAnchor(
                semanticLabel: t.room.replayRate,
                align: DsAlign.end,
                items: [
                  for (final rate in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    DsMenuItem(label: Text('${rate}x'), onPressed: () => unawaited(controller.setRate(rate))),
                ],
                builder: (context, menu, _) => DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: menu.toggle,
                  child: Text('${controller.rate}x'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The recording's parts, when the broadcast spans more than one file:
  /// one chip each, the on-screen part filled.
  Widget _parts(BuildContext context, ArchivePlaybackController controller) {
    final t = context.t;
    final current = controller.video?.id;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
        children: [
          for (final part in controller.segments.whereType<SoopArchivePart>())
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s8),
              child: DsButton(
                variant: part.id == current ? DsButtonVariant.primary : DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: '${t.room.replayParts} ${part.order}',
                onPressed: part.id == current ? null : () => unawaited(controller.open(part.id)),
                child: Text('P${part.order}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// The stand-in listenable the stage builds with before the controller
/// exists: never notifies, so the first frame is a dark stage with a way
/// back and nothing more.
final class ChangeTracker extends ChangeNotifier {
  new();
}

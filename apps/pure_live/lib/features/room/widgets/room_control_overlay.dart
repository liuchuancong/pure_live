import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LivePlayQuality;
import 'package:media_core/media_core.dart' show CastMedia;
import 'package:pure_live/features/cast/cast_providers.dart';
import 'package:pure_live/features/cast/cast_service.dart' show CastService;
import 'package:pure_live/features/cast/cast_sheet.dart';
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/features/room/widgets/room_bar_parts.dart';
import 'package:pure_live/features/room/widgets/room_on_video_controls.dart';
import 'package:pure_live/features/settings/widgets/settings_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/navigation/app_router.dart' show DanmakuSettingsRoute;
import 'package:pure_uikit/pure_uikit.dart';

/// The player's control bars, drawn over the video surface — the reference's
/// `VideoControllerPanel`.
///
/// They overlay the picture rather than riding under it: a room's video is the
/// one thing that must keep its pixels, and a control strip under it costs a
/// phone both a line of danmaku and the height to show it.
///
/// [immersive] is the difference that matters: in the normal presentation the
/// room header already carries the identity and the selectors already sit in
/// the resolution row, so the bar is transport only. Immersed, the header is
/// gone, so the bar takes the title, the exit affordance and the quality and
/// line chips too.
final class RoomControlOverlay extends ConsumerWidget {
  /// The bars over [identity]'s video.
  const new({
    required this.identity,
    this.immersive = false,
    this.compact = false,
    this.twoRows = false,
    this.onExit,
    super.key,
  });

  /// The room whose player these bars drive.
  final RoomIdentity identity;

  /// Whether the video owns the window (so these bars are the only chrome).
  final bool immersive;

  /// Narrow bar: fewer buttons, no inline volume slider.
  final bool compact;

  /// The reference's portrait-fullscreen arrangement (A07.2): the top chrome
  /// takes a second row — clock, battery and the picture-mode menu on a
  /// 48-high line of their own, where the upright fullscreen keeps the
  /// danmaku band clear above them.
  final bool twoRows;

  /// Leaves the immersive presentation; required when [immersive].
  final VoidCallback? onExit;

  /// The bar height, the reference's `barHeight`.
  static const _barHeight = 56.0;

  /// The second top row's height — the reference's `portraitRowHeight`.
  static const _rowHeight = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomControllerProvider(identity));
    final controller = ref.read(roomControllerProvider(identity).notifier);
    // The cast button only exists where casting can work at all, and it
    // lights up while a receiver is playing this room elsewhere.
    final castService = ref.watch(castServiceProvider);
    // The chrome slides out under the edge rather than blinking off, and the
    // bars stay mounted so a hover on desktop brings them back where they are.
    return Positioned.fill(
      child: MouseRegion(
        // The reference's hover lease: a bar that hides while the cursor sits
        // on it is worse than one that never hides.
        onEnter: (_) => controller.keepChromeWhileHovering(hovering: true),
        onExit: (_) => controller.keepChromeWhileHovering(hovering: false),
        child: Stack(
          children: [
            if (immersive)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                top: state.chromeVisible ? 0 : -(twoRows ? _barHeight + _rowHeight : _barHeight),
                left: 0,
                right: 0,
                child: _topBar(context, state, controller),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              bottom: state.chromeVisible || !immersive ? 0 : -_barHeight,
              left: 0,
              right: 0,
              child: _bottomBar(context, ref, state, controller, castService),
            ),
          ],
        ),
      ),
    );
  }

  /// The immersive top bar: exit, the room's title, and the barrage toggle the
  /// header would otherwise have carried. In the portrait arrangement the
  /// clock, the battery and the picture-mode menu take their own second row
  /// (the reference's `live-play-top-second-row`).
  Widget _topBar(BuildContext context, RoomState state, RoomController controller) {
    final padding = MediaQuery.paddingOf(context);
    return RoomOnVideoScrim(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _barHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, padding.top / 2, 4, 0),
              child: Row(
                children: [
                  RoomOnVideoButton(icon: Icons.arrow_back, tooltip: context.t.room.exitFullscreen, onPressed: onExit),
                  Expanded(
                    child: Text(
                      state.room?.content.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  RoomOnVideoButton(
                    icon: Icons.comment_outlined,
                    tooltip: state.barrageOn ? context.t.room.barrageOff : context.t.room.barrageOn,
                    selected: state.barrageOn,
                    onPressed: () => controller.setBarrage(on: !state.barrageOn),
                  ),
                ],
              ),
            ),
          ),
          if (twoRows)
            SizedBox(
              height: _rowHeight,
              // B09 c3 (audit B-11): a split screen or large display text can
              // crowd the row; it scrolls sideways rather than clipping.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const PlayerClock(),
                    const PlayerBattery(),
                    const SizedBox(width: 8),
                    if (state.isVerticalSource) const PortraitModeButton(),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The transport row: what plays, what the stream is, and how big it is.
  Widget _bottomBar(
    BuildContext context,
    WidgetRef ref,
    RoomState state,
    RoomController controller,
    CastService castService,
  ) {
    final padding = MediaQuery.paddingOf(context);
    final line = state.line;
    final canCast = !compact && castService.supported && line != null;
    return RoomOnVideoScrim(
      child: SizedBox(
        height: _barHeight + padding.bottom,
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, padding.bottom),
          child: Row(
            children: [
              RoomOnVideoButton(
                icon: state.paused ? Icons.play_arrow : Icons.pause,
                tooltip: state.paused ? context.t.room.play : context.t.room.pause,
                onPressed: state.playing ? controller.togglePause : null,
              ),
              if (state.engineStopped || state.streamError != null)
                RoomOnVideoButton(
                  icon: Icons.refresh,
                  tooltip: context.t.common.retry,
                  onPressed: () => controller.retry(),
                ),
              if (!compact)
                RoomOnVideoButton(
                  icon: state.muted ? Icons.volume_off : Icons.volume_up,
                  tooltip: state.muted ? context.t.room.unmute : context.t.room.mute,
                  onPressed: controller.toggleMute,
                ),
              if (!compact) RoomOnVideoSlider(value: state.muted ? 0 : state.volume, onChanged: controller.setVolume),
              if (immersive && state.qualities.isNotEmpty)
                _StreamChip(
                  state: state,
                  compact: compact,
                  onSelect: (quality) => controller.openLines(quality: quality),
                ),
              const Spacer(),
              if (!compact)
                PureMenu(
                  items: [
                    PureMenuItem(
                      id: 'contain',
                      label: context.t.settings.fitDefault,
                      icon: Icons.fit_screen_outlined,
                      onTap: () => controller.setVideoFit(BoxFit.contain),
                    ),
                    PureMenuItem(
                      id: 'cover',
                      label: context.t.settings.fitCrop,
                      icon: Icons.crop_free,
                      onTap: () => controller.setVideoFit(BoxFit.cover),
                    ),
                    PureMenuItem(
                      id: 'fill',
                      label: context.t.settings.fitFillScreen,
                      icon: Icons.open_in_full,
                      onTap: () => controller.setVideoFit(BoxFit.fill),
                    ),
                    PureMenuItem(
                      id: 'fitHeight',
                      label: context.t.settings.fitHeight,
                      icon: Icons.height,
                      onTap: () => controller.setVideoFit(BoxFit.fitHeight),
                    ),
                    PureMenuItem(
                      id: 'fitWidth',
                      label: context.t.settings.fitWidth,
                      icon: Icons.width_full,
                      onTap: () => controller.setVideoFit(BoxFit.fitWidth),
                    ),
                    PureMenuItem(
                      id: 'scaleDown',
                      label: context.t.settings.fitScaleDown,
                      icon: Icons.compress,
                      onTap: () => controller.setVideoFit(BoxFit.scaleDown),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(Icons.aspect_ratio, color: Colors.white, size: 22),
                  ),
                ),
              if (!compact)
                PureMenu(
                  items: [
                    for (final rate in const [0.75, 1.0, 1.25, 1.5, 2.0])
                      PureMenuItem(
                        id: '$rate',
                        label: rate == 1.0 ? context.t.room.rateNormal : '${rate}x',
                        onTap: () => controller.setRate(rate),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(Icons.speed, color: Colors.white, size: 22),
                  ),
                ),
              if (!compact)
                RoomOnVideoButton(
                  icon: Icons.lock_open,
                  tooltip: context.t.room.lock,
                  onPressed: controller.toggleLock,
                ),
              // The two window surfaces media_core's driver can put the whole
              // window into; they only exist where the window can be resized
              // at all, and only once a stream is up (the tile takes the
              // video's shape from the first frame it saw).
              if (controller.windowPresentationAvailable)
                RoomOnVideoButton(
                  key: const ValueKey('room-pip'),
                  icon: Icons.picture_in_picture_alt_rounded,
                  tooltip: state.presentation == RoomPresentation.pip ? context.t.room.exitPip : context.t.room.pip,
                  selected: state.presentation == RoomPresentation.pip,
                  onPressed: state.playing
                      ? () => controller.setPresentation(
                          state.presentation == RoomPresentation.pip ? RoomPresentation.normal : RoomPresentation.pip,
                        )
                      : null,
                ),
              if (controller.windowPresentationAvailable)
                RoomOnVideoButton(
                  key: const ValueKey('room-mini'),
                  icon: Icons.picture_in_picture_rounded,
                  tooltip: state.presentation == RoomPresentation.miniWindow
                      ? context.t.room.exitMiniWindow
                      : context.t.room.miniWindow,
                  selected: state.presentation == RoomPresentation.miniWindow,
                  onPressed: state.playing
                      ? () => controller.setPresentation(
                          state.presentation == RoomPresentation.miniWindow
                              ? RoomPresentation.normal
                              : RoomPresentation.miniWindow,
                        )
                      : null,
                ),
              // The danmaku settings, one tap from the picture (the
              // reference's `danmaku_settings` button).
              if (!compact)
                RoomOnVideoButton(
                  key: const ValueKey('room-danmaku-settings'),
                  icon: Icons.subtitles_outlined,
                  tooltip: context.t.settings.danmakuTitle,
                  onPressed: () => unawaited(const DanmakuSettingsRoute().push<void>(context)),
                ),
              if (canCast)
                RoomOnVideoButton(
                  key: const ValueKey('room-cast'),
                  icon: Icons.cast,
                  tooltip: context.t.cast.title,
                  selected: castService.isCasting,
                  onPressed: () => unawaited(
                    showCastSheet(
                      context,
                      ref,
                      media: CastMedia(url: line.url, title: state.room?.content.title ?? '', headers: line.headers),
                      // The TV plays its own fetch now; the local engine
                      // stands down so the room does not keep decoding.
                      onCastStarted: () => controller.takeLocalControl(pause: true),
                    ),
                  ),
                ),
              RoomOnVideoButton(
                icon: state.presentation == RoomPresentation.normal ? Icons.fullscreen : Icons.fullscreen_exit,
                tooltip: state.presentation == RoomPresentation.normal
                    ? context.t.room.fullscreen
                    : context.t.room.exitFullscreen,
                onPressed: () => controller.setPresentation(
                  state.presentation == RoomPresentation.normal ? RoomPresentation.fullscreen : RoomPresentation.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quality and line chip the immersive bar carries in place of the
/// resolution row, the reference's `FullscreenStreamSelectorButton`.
final class _StreamChip extends ConsumerWidget {
  const new({required this.state, required this.compact, required this.onSelect});

  final RoomState state;
  final bool compact;
  final ValueChanged<LivePlayQuality> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RoomOnVideoChip(
    label: state.switching
        ? ''
        : '${state.quality?.label ?? ''} · ${state.line?.lineLabel ?? context.t.room.lineN(n: '1')}',
    icon: Icons.tune,
    busy: state.switching,
    dense: compact,
    onTap: state.switching ? null : () => _pick(context, ref),
  );

  /// The picker rises from the bottom edge on a phone and centres on a desktop
  /// window, like every other floating surface in the app.
  void _pick(BuildContext context, WidgetRef ref) {
    unawaited(
      showSettingsSurface<void>(
        context,
        ref.settingsFormFactor,
        title: context.t.toolbox.selectQuality,
        body: (surfaceContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final quality in state.qualities)
              PureListRow(
                title: quality.label,
                selected: quality == state.quality,
                onTap: () {
                  Navigator.of(surfaceContext).pop();
                  onSelect(quality);
                },
                divided: false,
              ),
          ],
        ),
      ),
    );
  }
}

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
import 'package:pure_live/l10n/generated/strings.g.dart';
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
              child: _bottomBar(context, state, controller, castService),
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
    return _Scrim(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _barHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, padding.top / 2, 4, 0),
              child: Row(
                children: [
                  _BarButton(icon: Icons.arrow_back, tooltip: context.t.room.exitFullscreen, onPressed: onExit),
                  Expanded(
                    child: Text(
                      state.room?.content.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _BarButton(
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
  Widget _bottomBar(BuildContext context, RoomState state, RoomController controller, CastService castService) {
    final padding = MediaQuery.paddingOf(context);
    final line = state.line;
    final canCast = !compact && castService.supported && line != null;
    return _Scrim(
      child: SizedBox(
        height: _barHeight + padding.bottom,
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, padding.bottom),
          child: Row(
            children: [
              _BarButton(
                icon: state.paused ? Icons.play_arrow : Icons.pause,
                tooltip: state.paused ? context.t.room.play : context.t.room.pause,
                onPressed: state.playing ? controller.togglePause : null,
              ),
              if (state.engineStopped || state.streamError != null)
                _BarButton(icon: Icons.refresh, tooltip: context.t.common.retry, onPressed: () => controller.retry()),
              if (!compact)
                _BarButton(
                  icon: state.muted ? Icons.volume_off : Icons.volume_up,
                  tooltip: state.muted ? context.t.room.unmute : context.t.room.mute,
                  onPressed: controller.toggleMute,
                ),
              if (!compact)
                SizedBox(
                  width: 96,
                  child: _VolumeSlider(value: state.muted ? 0 : state.volume, onChanged: controller.setVolume),
                ),
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
                _BarButton(icon: Icons.lock_open, tooltip: context.t.room.lock, onPressed: controller.toggleLock),
              // The two window surfaces media_core's driver can put the whole
              // window into; they only exist where the window can be resized
              // at all, and only once a stream is up (the tile takes the
              // video's shape from the first frame it saw).
              if (controller.windowPresentationAvailable)
                _BarButton(
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
                _BarButton(
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
              if (canCast)
                _BarButton(
                  key: const ValueKey('room-cast'),
                  icon: Icons.cast,
                  tooltip: context.t.cast.title,
                  selected: castService.isCasting,
                  onPressed: () => unawaited(
                    showCastSheet(
                      context,
                      media: CastMedia(url: line.url, title: state.room?.content.title ?? '', headers: line.headers),
                      // The TV plays its own fetch now; the local engine
                      // stands down so the room does not keep decoding.
                      onCastStarted: () => controller.takeLocalControl(pause: true),
                    ),
                  ),
                ),
              _BarButton(
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

/// The gradient the bars sit on, so white glyphs read over a bright picture.
final class _Scrim extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0x99000000), Color(0x00000000)],
      ),
    ),
    child: child,
  );
}

/// A glyph on the video. The overlay needs white regardless of the app theme —
/// the picture behind it is not the app's surface, so it is not dressed by the
/// tokens; the app's own surfaces keep using `PureIconButton`.
final class _BarButton extends StatelessWidget {
  const new({required this.icon, required this.tooltip, this.onPressed, this.selected = false, super.key});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Ink(
      width: 44,
      height: 44,
      decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white24 : Colors.transparent),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Icon(icon, color: onPressed == null ? Colors.white38 : Colors.white, size: 22),
      ),
    ),
  );
}

/// The volume slider on the scrim: the token slider would draw itself in the
/// app's surfaces on top of a video, so the bar keeps the raw Material one with
/// an explicit white track.
final class _VolumeSlider extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      trackHeight: 3,
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white38,
      thumbColor: Colors.white,
      overlayColor: Colors.white24,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
  );
}

/// The quality and line chip the immersive bar carries in place of the
/// resolution row, the reference's `FullscreenStreamSelectorButton`.
final class _StreamChip extends StatelessWidget {
  const new({required this.state, required this.compact, required this.onSelect});

  final RoomState state;
  final bool compact;
  final ValueChanged<LivePlayQuality> onSelect;

  @override
  Widget build(BuildContext context) {
    final label = state.switching
        ? ''
        : '${state.quality?.label ?? ''} · ${state.line?.lineLabel ?? context.t.room.lineN(n: '1')}';
    return InkWell(
      onTap: state.switching ? null : () => _pick(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.switching) const PureSpinner(size: 14) else const Icon(Icons.tune, size: 17, color: Colors.white),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 90 : 150),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final quality in state.qualities)
                ListTile(
                  title: Text(
                    quality.label,
                    style: TextStyle(
                      fontWeight: quality == state.quality ? FontWeight.w700 : null,
                      color: quality == state.quality ? Theme.of(sheetContext).colorScheme.primary : null,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelect(quality);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

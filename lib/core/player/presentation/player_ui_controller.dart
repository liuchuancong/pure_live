import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:pure_live/core/index.dart';

/// What the shared player surface needs from whoever owns playback.
///
/// The gesture layer, the progress bar and the "leave the picture" half of the
/// control bar are the same on every surface this app plays video on: a live
/// room and a recorded file differ in *where the media comes from*, not in how a
/// viewer scrubs, changes volume, or leaves the picture. Those widgets live in
/// Core, which may not know about a room, a recording or a quality list — so they
/// talk to this instead, and each player supplies its own implementation.
///
/// Deliberately small: everything a shared control can drive, and nothing about
/// rooms, files, platform sites or EPG. A member belongs here only when at least
/// two players need it.
///
/// Responsibilities:
///
/// - expose play state, position and the transport actions
/// - expose the surface gestures' two targets: brightness and volume
/// - expose the danmaku surface a player is rendering
///
/// It does not:
///
/// - own playback (the kernel handle does)
/// - know which source is playing
/// - carry room, file or quality state
abstract interface class PlayerUiController {
  /// Whether the picture is currently playing.
  bool get uiIsPlaying;

  /// How far into the media playback is.
  Duration get uiPosition;

  /// Total length, or zero when the source does not report one (a live stream).
  Duration get uiDuration;

  /// Playback speed multiplier.
  double get uiRate;

  /// Starts or resumes playback.
  Future<void> uiPlay();

  /// Pauses playback.
  Future<void> uiPause();

  /// Jumps to an absolute position, clamped by the implementation.
  Future<void> uiSeekTo(Duration position);

  /// Sets the playback speed.
  Future<void> uiSetRate(double rate);

  /// Leaves the player surface: fullscreen, picture-in-picture or the small
  /// window depending on the host. Returns false when the player cannot.
  Future<bool> uiRequestExit();

  /// The current volume in `0..1`, or null when this player cannot report one.
  Future<double?> uiVolume();

  /// Applies a volume in `0..1`.
  Future<void> uiSetVolume(double value);

  /// The screen brightness in `0..1`, or null when the platform has none.
  Future<double?> uiBrightness();

  /// Applies a screen brightness in `0..1`.
  Future<void> uiSetBrightness(double value);

  /// Whether a drag on the left half of the surface may change brightness.
  ///
  /// False on a desktop, where the left drag is not a brightness gesture: the
  /// wheel and the keyboard own it there.
  bool get uiSupportsBrightnessGesture;

  /// The danmaku surface to overlay on the picture, or null when this player has
  /// none (a recording whose chat file is missing, a room with chat switched
  /// off).
  Widget? buildDanmakuSurface(BuildContext context);
}

/// Which half of the surface a brightness/volume drag started on.
enum PlayerDragSide { brightness, volume }

/// Resolves the side from a surface-local drag start.
///
/// The split is the surface's own midpoint, not the window's: the small window
/// and a split-view pane both hand their own box to the gesture.
PlayerDragSide resolvePlayerDragSide(double localDx, double surfaceWidth) {
  return localDx > surfaceWidth / 2 ? PlayerDragSide.volume : PlayerDragSide.brightness;
}

/// Launcher home-gesture strip (swipe up to the system desktop) at the bottom of
/// mobile screens.
///
/// Android and iOS deliver the pointer to the app first and cancel it once the
/// launcher recognises the gesture, so a brightness/volume drag started inside
/// the strip always ends with a half-applied change and no way to undo it. The
/// strip never starts such a drag.
const double systemHomeGestureZoneHeight = 48;

/// Whether a surface-local drag start lies inside the launcher gesture strip.
@visibleForTesting
bool startsInSystemHomeGestureZone({required Offset localPosition, required Size surfaceSize}) {
  if (surfaceSize.height <= 0) return false;
  final zoneHeight = systemHomeGestureZoneHeight.clamp(0.0, surfaceSize.height / 3);
  return localPosition.dy >= surfaceSize.height - zoneHeight;
}

/// The full-surface gesture layer every player shares.
///
/// A vertical drag on the left half changes screen brightness, on the right half
/// the volume, and both show the same card while they run. The layer owns only
/// the gesture and the readout; the values themselves come from
/// [PlayerUiController], so a live room keeps writing to the room's saved volume
/// while a recording writes to the ordinary player volume.
///
/// Responsibilities:
///
/// - recognise the brightness/volume drags and the wheel
/// - show the value card for the duration of the gesture
/// - ignore drags that would race the system's own home gesture
///
/// It does not:
///
/// - store or persist a level (the controller does)
/// - draw the picture or the control bars
/// - handle taps (the page places its own tap target)
class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({super.key, required this.controller, this.child, this.enabled = true});

  final PlayerUiController controller;

  /// The surface the gesture sits on; null makes the layer a transparent
  /// overlay, which is how a page stacks it over its own picture.
  final Widget? child;

  /// Whether the layer takes brightness/volume drags at all.
  ///
  /// A host that owns the vertical drag for its own transition — the room's
  /// portrait-panel restore swipe, for example — turns this off while that
  /// transition is available, so one drag never means two things.
  final bool enabled;

  @override
  State<PlayerGestureLayer> createState() => PlayerGestureLayerState();
}

class PlayerGestureLayerState extends State<PlayerGestureLayer> {
  static const Duration _hideAfter = Duration(seconds: 1);

  /// Full travel of the surface maps to a quarter of the level range, which is
  /// the sensitivity the live room has always used.
  static const double _sensitivity = 0.25;

  Timer? _hideTimer;

  /// Hidden until the first drag: a HUD that greets the viewer with
  /// "brightness 100%" before any gesture happened is just noise.
  bool _visible = false;
  PlayerDragSide _side = PlayerDragSide.brightness;
  double _value = 1;
  bool _systemGesture = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Size get _surfaceSize {
    final size = context.size;
    if (size != null && size.height > 0) return size;
    return MediaQuery.sizeOf(context);
  }

  void _keepVisible() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _visible = false);
    });
    if (!_visible) setState(() => _visible = true);
  }

  Future<void> _apply(Offset localPosition, Offset delta, Size size) async {
    if (delta.distance < 0.5 || size.height <= 0) return;
    final resolved = resolvePlayerDragSide(localPosition.dx, size.width);
    // A desktop adjusts brightness with the wheel and the keyboard; the left
    // drag would otherwise be a second, invisible way to change it.
    if (resolved == PlayerDragSide.brightness && !widget.controller.uiSupportsBrightnessGesture) return;

    if (_side != resolved || !_visible) {
      _side = resolved;
      try {
        final observed = resolved == PlayerDragSide.brightness
            ? await widget.controller.uiBrightness()
            : await widget.controller.uiVolume();
        if (!mounted) return;
        setState(() => _value = (observed ?? _value).clamp(0.0, 1.0).toDouble());
      } catch (_) {
        return;
      }
    }

    if (!mounted) return;
    _keepVisible();

    final target = (_value - delta.dy / (size.height / 2) * _sensitivity).clamp(0.0, 1.0).toDouble();
    if ((target - _value).abs() <= 0.001) return;
    setState(() => _value = target);
    if (_side == PlayerDragSide.brightness) {
      unawaited(widget.controller.uiSetBrightness(target));
    } else {
      unawaited(widget.controller.uiSetVolume(target));
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _systemGesture = startsInSystemHomeGestureZone(localPosition: details.localPosition, surfaceSize: _surfaceSize);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _systemGesture) return;
    unawaited(_apply(details.localPosition, details.delta, _surfaceSize));
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _systemGesture = false;
  }

  IconData get _icon {
    if (_side == PlayerDragSide.brightness) {
      if (_value <= 0) return Icons.brightness_low;
      return _value < 0.5 ? Icons.brightness_medium : Icons.brightness_high;
    }
    if (_value <= 0) return Icons.volume_mute;
    return _value < 0.5 ? Icons.volume_down : Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          unawaited(_apply(event.localPosition, event.scrollDelta, _surfaceSize));
        }
      },
      child: GestureDetector(
        // The layer owns the drag even where nothing is painted, which is how a
        // page stacks it under its own overlays: the video widget below is
        // opaque only to the tap targets the page itself adds.
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onVerticalDragCancel: () => _systemGesture = false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.child != null) widget.child!,
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _visible ? 0.8 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: Card(
                    color: Colors.black,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon, color: Colors.white),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 100,
                                height: 20,
                                child: LinearProgressIndicator(
                                  value: _value,
                                  backgroundColor: Colors.white38,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '${(_value * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether this platform has a screen brightness the app may set.
///
/// Kept here rather than in a player so the gesture layer can decide it without
/// reaching into a domain; the two mobile platforms are the only ones exposing a
/// per-application brightness.
bool get platformSupportsBrightness => Platform.isAndroid || Platform.isIOS;

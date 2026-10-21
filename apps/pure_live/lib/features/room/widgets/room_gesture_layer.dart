import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart'
    show PlatformScreenBrightnessService, PlatformSystemVolumeService, ScreenBrightnessService, SystemVolumeService;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app_providers.dart' show environmentProvider;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// What a vertical drag over the picture changes.
enum RoomGestureLevel {
  /// The device's media volume, or the player's own when the device exposes
  /// no volume channel (most desktops).
  volume,

  /// The screen's brightness, on the devices that let an app write it.
  brightness,
}

/// The picture's gesture grammar, in one layer: a tap shows or hides the
/// chrome, a double tap takes or leaves full screen, a vertical drag on the
/// right half is the volume and on the left the brightness, and the wheel is
/// the volume — a level pill shows while either changes.
///
/// The portrait fullscreen's own move stays: an upward fling begun low on
/// the picture restores the panel, and it wins over the brightness half,
/// because that fling is how the panel is brought back with one hand.
///
/// A device whose volume or brightness channel is missing keeps the gesture
/// working on the player's own volume, or skips the half it cannot own; the
/// probe happens once per gesture, and a failure simply leaves the drag
/// inert rather than surfacing an error over the picture.
final class RoomGestureLayer extends ConsumerStatefulWidget {
  /// Wraps [child] — the picture and everything over it — in the gestures.
  const new({
    required this.controller,
    required this.state,
    required this.immersive,
    required this.child,
    this.onPortraitRestore,
    super.key,
  });

  /// The room whose volume, chrome and presentation the gestures move.
  final RoomController controller;

  /// The room's current state: lock, volume and the chrome's row count.
  final RoomState state;

  /// Whether the picture currently owns the window — the double tap's
  /// direction.
  final bool immersive;

  /// The picture and its overlays.
  final Widget child;

  /// Brings the portrait panel back; null outside the portrait fullscreen.
  final VoidCallback? onPortraitRestore;

  @override
  ConsumerState<RoomGestureLayer> createState() => _RoomGestureLayerState();
}

final class _RoomGestureLayerState extends ConsumerState<RoomGestureLayer> {
  /// How much of the picture a full-height drag travels; the reference's
  /// `BrightnessVolumnDargArea` moved a level by 1.2 per screen.
  static const double _travel = 1.2;

  /// The lowest strip an upward drag restores the portrait panel from.
  static const double _restoreZone = 160;

  /// How long the level pill stays after the last change.
  static const Duration _pillLinger = Duration(seconds: 1);

  /// The debounce before a wheel-adjusted volume is written to preferences.
  static const Duration _saveLinger = Duration(milliseconds: 600);

  RoomGestureLevel? _showing;
  double _level = 0;
  Timer? _hide;
  Timer? _save;

  /// The drag's starting point, down the picture.
  double? _downY;

  /// Which half the drag belongs to; null while the level is still reading.
  RoomGestureLevel? _dragging;

  /// How far the finger has travelled up (negative) since it went down — the
  /// restore fling's measure.
  double _upward = 0;

  /// The level a drag states is being read from the device: moves wait for
  /// it, so the first one never jumps from zero.
  bool _reading = false;

  /// A frame is already booked to tell the device the latest level.
  int? _sending;

  /// What the device has not heard yet.
  RoomGestureLevel? _unsent;

  final SystemVolumeService _systemVolume = const PlatformSystemVolumeService();
  final ScreenBrightnessService _brightness = const PlatformScreenBrightnessService();

  @override
  void dispose() {
    if (_sending case final id?) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    }
    _hide?.cancel();
    _save?.cancel();
    super.dispose();
  }

  /// Whether the device owns the volume channel; the app's own volume is the
  /// fallback everywhere else.
  bool get _deviceVolume => _deviceVolumeUsable;

  /// Probed once and remembered: some desktops answer the capability call
  /// with "no mixer", and asking again on every drag would be wasted work.
  bool _deviceVolumeUsable = true;

  /// The wheel writes the player's volume, which is the room's; the write
  /// lands once the wheel rests.
  void _nudgeVolume(double delta) {
    final next = (widget.state.volume + delta).clamp(0.0, 1.0);
    widget.controller.setVolume(next);
    _show(RoomGestureLevel.volume, next);
    _scheduleSave();
  }

  void _scheduleSave() {
    _save?.cancel();
    _save = Timer(_saveLinger, _persistVolume);
  }

  /// Writes the level the room settled on as the device class's default, the
  /// way the volume dialog's slider does — a phone and a desktop keep their
  /// own answers.
  void _persistVolume() {
    if (!mounted) {
      return;
    }
    final level = widget.state.volume;
    final phone = ref.read(environmentProvider).runtime.formFactor == FormFactor.phone;
    unawaited(
      ref
          .read(appPreferencesProvider.notifier)
          .update(
            (preferences) => phone
                ? preferences.copyWith(defaultMobileVolume: level)
                : preferences.copyWith(defaultDesktopVolume: level),
          ),
    );
  }

  void _show(RoomGestureLevel kind, double level) {
    _hide?.cancel();
    setState(() {
      _showing = kind;
      _level = level.clamp(0.0, 1.0);
    });
    _hide = Timer(_pillLinger, () {
      if (mounted) {
        setState(() => _showing = null);
      }
    });
  }

  Future<double?> _readLevel(RoomGestureLevel kind) async {
    try {
      return switch (kind) {
        RoomGestureLevel.brightness => (await _brightness.getBrightness()) / 100,
        RoomGestureLevel.volume when _deviceVolume => (await _systemVolume.getVolume()) / 100,
        RoomGestureLevel.volume => widget.state.volume,
      };
    } on Object {
      return null;
    }
  }

  /// Tells the device (or the player) a level, batching native calls to one
  /// per frame: a touch screen samples far faster than the channel wants.
  void _applySoon(RoomGestureLevel kind) {
    _show(kind, _level);
    _unsent = kind;
    _sending ??= SchedulerBinding.instance.scheduleFrameCallback((_) {
      _sending = null;
      final unsent = _unsent;
      _unsent = null;
      if (unsent != null && mounted) {
        unawaited(_apply(unsent, _level));
      }
    });
  }

  Future<void> _apply(RoomGestureLevel kind, double level) async {
    try {
      switch (kind) {
        case RoomGestureLevel.brightness:
          await _brightness.setBrightness((level * 100).round());
        case RoomGestureLevel.volume when _deviceVolume:
          await _systemVolume.setVolume((level * 100).round());
        case RoomGestureLevel.volume:
          widget.controller.setVolume(level);
      }
    } on Object {
      // A channel that answers "no" mid-gesture (an endpoint disappears) is
      // a channel this drag does not have; the picture keeps its own volume.
      if (kind == RoomGestureLevel.volume) {
        _deviceVolumeUsable = false;
        widget.controller.setVolume(level);
      }
    }
  }

  void _onDragStart(DragStartDetails details) {
    final size = context.size ?? Size.zero;
    _dragging = null;
    _upward = 0;
    if (size.isEmpty) {
      return;
    }
    final leftHalf = details.localPosition.dx < size.width * 0.5;
    // Reading the level can fail on a device without the channel; the drag
    // then belongs to the other half's kind or to the player's volume.
    final kind = leftHalf ? RoomGestureLevel.brightness : RoomGestureLevel.volume;
    _dragging = kind;
    _reading = true;
    unawaited(
      _readLevel(kind).then((value) {
        if (!mounted) {
          return;
        }
        if (value == null) {
          _dragging = kind == RoomGestureLevel.brightness ? null : RoomGestureLevel.volume;
          _reading = false;
          return;
        }
        _level = value;
        _reading = false;
      }),
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _upward += details.delta.dy;
    final kind = _dragging;
    final height = context.size?.height ?? 0;
    if (kind == null || height <= 0 || _reading) {
      return;
    }
    _level = (_level - details.delta.dy / height * _travel).clamp(0.0, 1.0);
    _applySoon(kind);
  }

  void _onDragEnd(DragEndDetails details) {
    final restore = widget.onPortraitRestore;
    final velocity = details.primaryVelocity ?? 0;
    final kind = _dragging;
    _dragging = null;
    // The upward fling out of the portrait fullscreen: it must start low on
    // the picture, travel up, and carry speed — a short drag is a level.
    if (restore != null && _downY != null && (context.size?.height ?? 0) - _downY! < _restoreZone) {
      if (velocity < -600 && _upward < -80) {
        restore();
      }
      return;
    }
    if (kind == RoomGestureLevel.volume) {
      _scheduleSave();
    }
  }

  void _onDragCancel() {
    _dragging = null;
    _reading = false;
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.state.locked;
    final showing = _showing;
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: locked ? null : () => widget.controller.revealChrome(toggle: widget.immersive),
      onDoubleTap: locked
          ? null
          : () => widget.controller.setPresentation(
              widget.immersive ? RoomPresentation.normal : RoomPresentation.fullscreen,
            ),
      onVerticalDragDown: locked ? null : (details) => _downY = details.localPosition.dy,
      onVerticalDragStart: locked ? null : _onDragStart,
      onVerticalDragUpdate: locked ? null : _onDragUpdate,
      onVerticalDragEnd: locked ? null : _onDragEnd,
      onVerticalDragCancel: locked ? null : _onDragCancel,
      child: Listener(
        onPointerSignal: (event) {
          if (locked || event is! PointerScrollEvent) {
            return;
          }
          final dy = event.scrollDelta.dy;
          if (dy != 0) {
            _nudgeVolume(dy > 0 ? -0.05 : 0.05);
          }
        },
        child: widget.child,
      ),
    );
    if (showing == null) {
      return content;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        IgnorePointer(
          child: Center(
            child: _LevelPill(kind: showing, level: _level),
          ),
        ),
      ],
    );
  }
}

/// The level pill: the gesture's glyph, a bar and the percentage, over a
/// dark plate so it reads on any picture.
final class _LevelPill extends StatelessWidget {
  const new({required this.kind, required this.level});

  final RoomGestureLevel kind;
  final double level;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final percent = (level * 100).round();
    final icon = switch (kind) {
      RoomGestureLevel.volume =>
        percent == 0
            ? Icons.volume_off_rounded
            : percent < 50
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded,
      RoomGestureLevel.brightness =>
        percent < 34
            ? Icons.brightness_low_rounded
            : percent < 67
            ? Icons.brightness_medium_rounded
            : Icons.brightness_high_rounded,
    };
    return DecoratedBox(
      key: ValueKey('gesture-level-${kind.name}'),
      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: level,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  color: theme.colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: theme.text.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clamps a level into the range a drag may take it.
double clampRoomGestureLevel(double level) => math.min(1, math.max(0, level));

import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show BatteryService, PlatformBatteryService;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The smaller pieces of the immersive bars — the reference's `bar_parts`:
/// the clock and battery of the top second row (A07.2/U.2c) and the portrait
/// fullscreen's picture-mode menu (U.2b).

/// The clock of the fullscreen bars (3.x `DatetimeInfo`): `21:36` in equal
/// digits; redrawn when the minute turns, nothing else.
class PlayerClock extends StatefulWidget {
  /// Creates the clock.
  const new({this.now = DateTime.now, super.key});

  /// The time source.
  final DateTime Function() now;

  @override
  State<PlayerClock> createState() => _PlayerClockState();
}

final class _PlayerClockState extends State<PlayerClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = widget.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _tick = Timer(next.difference(now) + const Duration(milliseconds: 50), () {
      if (!mounted) {
        return;
      }
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '${two(now.hour)}:${two(now.minute)}',
        key: const ValueKey('live-play-clock'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFeatures: [_tabular],
          shadows: [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 1))],
        ),
      ),
    );
  }
}

/// The tabular figures of the clock and the battery, so the row does not
/// jitter as the digits turn (Material's `.tabular` equivalent, spelled
/// through the font feature the overlay draws with).
const FontFeature _tabular = FontFeature.tabularFigures();

/// Reads the battery level in percent, null where there is none (a desktop,
/// a tablet without a battery cell, a platform that will not say).
Future<int?> readBatteryLevel({BatteryService service = const PlatformBatteryService()}) async {
  try {
    final level = await service.readLevel();
    return level < 0 ? null : level.clamp(0, 100);
  } on Object {
    return null;
  }
}

/// The battery of the fullscreen bars (3.x `BatteryInfo`): a 36 × 17 outline
/// with the percentage inside; nothing on a device without a battery
/// (U.2c change 4). Read once and then every minute; redrawn only when it
/// changes. [read] is injectable for tests, as the reference's own hook.
class PlayerBattery extends StatefulWidget {
  /// Creates the battery.
  const new({this.read = readBatteryLevel, super.key});

  /// Reads the level (percent), null for none.
  final Future<int?> Function() read;

  @override
  State<PlayerBattery> createState() => _PlayerBatteryState();
}

final class _PlayerBatteryState extends State<PlayerBattery> {
  /// The battery figure's size (B09 c5, audit B-18: at least 11; it was 9).
  static const double _fontSize = 11;

  int? _level;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    int? level;
    try {
      level = await widget.read();
    } on Object {
      // A battery that will not answer draws nothing, never an error box.
      level = null;
    }
    if (mounted && level != _level) {
      setState(() => _level = level);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      // The case grows with larger text instead of cutting the figure.
      child: ConstrainedBox(
        key: const ValueKey('live-play-battery'),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 17),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white24,
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                '$level',
                key: const ValueKey('live-play-battery-level'),
                style: const TextStyle(color: Colors.white, fontSize: _fontSize, height: 1, fontFeatures: [_tabular]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The portrait fullscreen's picture mode (U.2b: the 画面比例 icon, lit
/// while not on the plain 完整画面; a small menu, each mode named, the
/// current one carrying the tick). The picture is not dimmed and changes at
/// once — the layout reads this same preference live.
class PortraitModeButton extends ConsumerWidget {
  /// Creates the button.
  const new({super.key});

  static const List<(String, IconData)> _modes = [
    ('complete', Icons.fit_screen_outlined),
    ('ambient', Icons.blur_on),
    ('balanced', Icons.aspect_ratio),
    ('cover', Icons.crop_free),
  ];

  /// The name of one display mode, in the language on screen.
  static String modeName(BuildContext context, String mode) {
    final t = context.t;
    return switch (mode) {
      'ambient' => t.settings.portraitDisplayAmbient,
      'balanced' => t.settings.portraitDisplayBalanced,
      'cover' => t.settings.portraitDisplayCover,
      _ => t.settings.portraitDisplayComplete,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appPreferencesProvider).portraitDisplayMode;
    return PureMenu(
      items: [
        for (final (value, icon) in _modes)
          PureMenuItem(
            id: value,
            label: modeName(context, value),
            icon: value == current ? Icons.check : icon,
            onTap: () => unawaited(
              ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(portraitDisplayMode: value)),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(
          Icons.aspect_ratio,
          color: current == 'complete' ? Colors.white : const Color(0xFFFFD54F),
          size: 22,
        ),
      ),
    );
  }
}

/// The hint after entering the portrait fullscreen (3.x
/// `PortraitFullscreenEntryHint`): "已进入竖屏全屏 · 上滑恢复弹幕栏" above
/// the bottom bar, fading out after three seconds.
class PortraitEntryHint extends StatefulWidget {
  /// Creates the hint, [bottom] above the screen's lower edge.
  const new({required this.bottom, this.visibleFor = const Duration(seconds: 3), super.key});

  /// The distance from the lower edge.
  final double bottom;

  /// How long it shows.
  final Duration visibleFor;

  @override
  State<PortraitEntryHint> createState() => _PortraitEntryHintState();
}

final class _PortraitEntryHintState extends State<PortraitEntryHint> {
  bool _visible = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _hide = Timer(widget.visibleFor, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: widget.bottom,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: still ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: DecoratedBox(
              key: const ValueKey('live-play-portrait-hint'),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.t.room.portraitFullscreenRestoreHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

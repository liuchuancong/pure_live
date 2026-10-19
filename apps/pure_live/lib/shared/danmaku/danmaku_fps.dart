import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show DisplayRefreshRate, PlatformDisplayRefreshRateService;

/// The danmaku frame rate in use — the reference's `resolvedDanmakuFps`
/// (3.x's adaptive clock): the manual number when [automatic] is off, or
/// with it on the display's own maximum, capped by the refresh-rate mode
/// (`powerSaving`/`balanced` at 60, `performance` uncapped) and floored at
/// 30 — the [pip] variant floors at 15 and saves at 30, the small-window
/// surface's cheaper clock.
int resolvedDanmakuFps({
  required bool automatic,
  required int configured,
  required String mode,
  double? maxHz,
  double? currentHz,
  bool pip = false,
}) {
  final floor = pip ? 15 : 30;
  if (!automatic) {
    return configured.clamp(floor, 240);
  }
  final maximum = maxHz ?? 0;
  final current = currentHz ?? 0;
  final detected = maximum > 0 ? maximum : (current > 0 ? current : 60.0);
  final device = detected.round().clamp(floor, 240);
  return switch (mode) {
    'performance' => device,
    'balanced' => device.clamp(floor, 60),
    _ => device.clamp(floor, pip ? 30 : 60),
  };
}

/// The display's refresh-rate snapshot, or null where the platform cannot
/// say (a headless test run, an unsupported driver). The barrage's automatic
/// clock reads it; a null answer falls back to 60 inside
/// [resolvedDanmakuFps], exactly as the reference's does.
final displayRefreshRateProvider = StreamProvider<DisplayRefreshRate?>((ref) async* {
  const service = PlatformDisplayRefreshRateService();
  DisplayRefreshRate? first;
  try {
    first = await service.read();
  } on Object {
    first = null;
  }
  yield first;
  try {
    yield* service.watch();
  } on Object {
    // A platform that stops reporting leaves the first reading standing.
  }
});

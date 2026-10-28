import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, ValueNotifier, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show Offset, WidgetsBinding;

/// The Android floating window over other apps ("离开应用时自动小窗"), the app's
/// side of `FloatingRoomOverlay.kt` (channel `pure_live/floating_overlay`).
///
/// The window shows this app's *own* engine: the native side moves the engine's
/// view out of the activity into a small overlay window while the app is left,
/// so the playing room — its picture, its danmaku, its player — keeps running
/// untouched. No second engine, no second decoder, no handoff.
///
/// That is why this exists instead of `media_core_pip`'s Android backend: a
/// `flutter_overlay_window` overlay runs in a freshly created engine, and a
/// fresh engine registers no plugins, so none of the video backends this app
/// ships could render there.
///
/// The room page arms the window while a room plays and follows [active]: while
/// it is true the app draws the room in its floating player, which fills the
/// window's whole viewport.
final class FloatingOverlay {
  const FloatingOverlay._();

  static const MethodChannel _channel = MethodChannel('pure_live/floating_overlay');

  static bool _listening = false;

  /// Whether the app is drawing in the floating window right now.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Whether "display over other apps" is granted for this app.
  static final ValueNotifier<bool> permitted = ValueNotifier<bool>(false);

  /// Whether this host has the window at all: the native side ships on
  /// Android and nowhere else.
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts listening for the window's changes; safe to call again.
  static void listen() {
    if (!supported || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') active.value = call.arguments == true;
    });
    unawaited(refresh());
  }

  /// Looks at the permission again.
  static Future<bool> refresh() async {
    if (!supported) return false;
    permitted.value = await _invoke<bool>('status') ?? false;
    return permitted.value;
  }

  /// Opens the system's "display over other apps" page for this app.
  static Future<bool> openSettings() async => await _invoke<bool>('openSettings') ?? false;

  /// Arms the window for the next leave: [width] and [height] are the picture's
  /// logical pixels. A zero size — [disarm] — stops the next leave showing it.
  static Future<void> arm({required double width, required double height}) async {
    if (!supported) return;
    final ratio = _pixelRatio;
    await _invoke<void>('arm', <String, Object?>{
      'enabled': width > 0 && height > 0,
      'width': (width * ratio).round(),
      'height': (height * ratio).round(),
    });
  }

  /// Stops the next leave from showing the window.
  static Future<void> disarm() => arm(width: 0, height: 0);

  /// Moves the window by [delta] logical pixels (a drag on its title).
  static Future<void> moveBy(Offset delta) async {
    if (!supported) return;
    await _invoke<void>('move', <String, Object?>{'dx': delta.dx, 'dy': delta.dy});
  }

  /// Takes the window away; the app stays where the viewer left it, behind the
  /// other apps. The room page decides what closing means for the room.
  static Future<void> close() async {
    await _invoke<void>('close');
  }

  /// Brings the app back in front; the window goes as it returns.
  static Future<bool> backToApp() async => await _invoke<bool>('backToApp') ?? false;

  static double get _pixelRatio {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1 : views.first.devicePixelRatio;
  }

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on Object {
      // A build without the native side simply never shows the window; the
      // room stays in its page.
      return null;
    }
  }
}

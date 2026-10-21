import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The live room's hold on Android's back: while a room page holds it, the
/// activity takes every back — Android 13+'s gesture at overlay priority, and
/// the key vendor builds still deliver to `onBackPressed` — and hands it
/// here before Flutter could pop the room.
///
/// The overlay priority puts the room before the keyboard, which Android
/// otherwise closes first: a back while typing only closes the keyboard.
///
/// One holder at a time: a room page that opens over or instead of another
/// takes it, and the old page closing afterwards does not give it up.
final class RoomBackChannel {
  new _();

  /// The app's channel.
  static final RoomBackChannel instance = RoomBackChannel._();

  static const _channel = MethodChannel('pure_live/predictive_back');

  Object? _holder;
  Future<void> Function()? _onBack;
  bool _listening = false;

  /// Whether a room holds the back.
  bool get held => _holder != null;

  /// [holder] takes the back: [onBack] runs for each one.
  Future<void> hold(Object holder, Future<void> Function() onBack) async {
    _holder = holder;
    _onBack = onBack;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_handle);
    }
    await _setEnabled(enabled: true);
  }

  /// [holder] gives the back up; nothing happens when another holds it now.
  Future<void> release(Object holder) async {
    if (!identical(_holder, holder)) {
      return;
    }
    _holder = null;
    _onBack = null;
    await _setEnabled(enabled: false);
  }

  /// Forgets the holder and the handler (tests).
  @visibleForTesting
  void reset() {
    _holder = null;
    _onBack = null;
    _listening = false;
    _channel.setMethodCallHandler(null);
  }

  Future<void> _setEnabled({required bool enabled}) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on PlatformException {
      // The route's PopScope stays the fallback.
    } on MissingPluginException {
      // Tests and other embeddings: the same.
    }
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'backInvoked') {
      return;
    }
    if (_keyboardUp()) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    await _onBack?.call();
  }

  static bool _keyboardUp() =>
      WidgetsBinding.instance.platformDispatcher.views.any((view) => view.viewInsets.bottom > 0) &&
      FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;
}

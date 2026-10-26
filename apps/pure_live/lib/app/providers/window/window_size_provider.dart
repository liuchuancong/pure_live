import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show PixelRect, WindowEvent, WindowGeometry;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/providers/window/window_providers.dart' show desktopWindowHostProvider;

/// The main window's size, remembered between starts and applied from the
/// General pane.
///
/// The window's place on screen is deliberately not stored here: the shell's
/// own geometry store owns placement, while this setting owns the frame the
/// viewer asked for. Applying a size centers the window on the display it is
/// already on, and a resize by the window's edges updates the stored frame so
/// the next start keeps what the viewer last chose.
final class WindowSizeController extends Notifier<Size?> {
  /// The persisted width key.
  static const String widthKey = 'window.width';

  /// The persisted height key.
  static const String heightKey = 'window.height';

  /// The smallest accepted width, matching the reference.
  static const double minWidth = 400;

  /// The smallest accepted height, matching the reference.
  static const double minHeight = 300;

  /// The largest accepted dimension, matching the reference.
  static const double maxDimension = 16384;

  Timer? _debounce;
  StreamSubscription<WindowEvent>? _events;
  bool _started = false;

  @override
  Size? build() {
    ref.onDispose(() {
      _debounce?.cancel();
      unawaited(_events?.cancel());
      _events = null;
    });
    try {
      final width = StoragePrefs.getInt(widthKey);
      final height = StoragePrefs.getInt(heightKey);
      if (width == null || height == null) return null;
      final size = Size(width.toDouble(), height.toDouble());
      return _isValid(size) ? size : null;
    } on Object {
      return null;
    }
  }

  /// Reads the window, applies the stored size when there is one, then keeps
  /// the stored size in step with the viewer's own resizes. Called once per
  /// process from the desktop root after the first frame.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final host = ref.read(desktopWindowHostProvider);
      final stored = state;
      if (stored != null) {
        await _apply(stored);
      } else {
        final geometry = await host.geometry();
        if (!geometry.maximized && _isValid(_sizeOf(geometry))) {
          state = _sizeOf(geometry);
        }
      }
      _events = host.events.listen((event) {
        if (event != WindowEvent.resized && event != WindowEvent.restored && event != WindowEvent.unmaximised) {
          return;
        }
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 450), () => unawaited(_capture()));
      });
    } on Object {
      // A missing host or a failed first apply leaves the setting stored for
      // the next start; the pane still shows the last known size.
    }
  }

  /// Applies [size] and stores it. Returns null on success, or the transport's
  /// error text when the window manager refused.
  Future<String?> apply(Size size) async {
    if (!_isValid(size)) return 'out_of_range';
    try {
      await _apply(size);
      return null;
    } on Object catch (error) {
      return '$error';
    }
  }

  Future<void> _apply(Size size) async {
    final host = ref.read(desktopWindowHostProvider);
    final current = await host.geometry();
    final frame = current.frame;
    final width = size.width.round();
    final height = size.height.round();
    final left = frame.left + (frame.width - width) ~/ 2;
    final top = frame.top + (frame.height - height) ~/ 2;
    await host.setGeometry(
      WindowGeometry(
        frame: PixelRect(left, top, width, height),
        maximized: false,
        displayId: current.displayId,
        scaleFactor: current.scaleFactor,
      ),
    );
    await host.center();
    state = size;
    _persist(size);
  }

  Future<void> _capture() async {
    if (!ref.mounted) return;
    try {
      final geometry = await ref.read(desktopWindowHostProvider).geometry();
      if (geometry.maximized) return;
      final size = _sizeOf(geometry);
      if (!_isValid(size) || size == state) return;
      state = size;
      _persist(size);
    } on Object {
      // A window that vanished mid-resize has no frame worth keeping.
    }
  }

  static Size _sizeOf(WindowGeometry geometry) =>
      Size(geometry.frame.width.toDouble(), geometry.frame.height.toDouble());

  static bool _isValid(Size size) =>
      size.width >= minWidth && size.height >= minHeight && size.width <= maxDimension && size.height <= maxDimension;

  void _persist(Size size) {
    unawaited(StoragePrefs.setInt(widthKey, size.width.round()));
    unawaited(StoragePrefs.setInt(heightKey, size.height.round()));
  }
}

/// The remembered/current main-window size; null before the first read.
final windowSizeProvider = NotifierProvider<WindowSizeController, Size?>(WindowSizeController.new);

import 'package:live_device/src/display/brightness/screen_brightness_scope.dart';

/// Reliability of brightness writes on the currently detected backend.
enum ScreenBrightnessWriteSupport {
  /// The backend reports reliable, verifiable brightness writes.
  supported,

  /// The operating system exposes an API, but hardware or policy may reject it.
  bestEffort,

  /// No writable brightness backend is currently available.
  unsupported,
}

/// Runtime capabilities reported by the active display backend.
final class ScreenBrightnessCapabilities {
  /// Creates an immutable capability snapshot.
  new({
    required this.canRead,
    required this.canWrite,
    required this.canObserve,
    required this.writeSupport,
    required Iterable<ScreenBrightnessScope> supportedScopes,
    required this.targetsPrimaryDisplay,
    required this.requiresSystemPermission,
    required this.backend,
  }) : supportedScopes = Set<ScreenBrightnessScope>.unmodifiable(supportedScopes);

  /// Whether the active backend can read a brightness value.
  final bool canRead;

  /// Whether the active backend exposes a write operation.
  final bool canWrite;

  /// Whether the active backend can observe brightness changes.
  final bool canObserve;

  /// Reliability of brightness writes on the current backend.
  final ScreenBrightnessWriteSupport writeSupport;

  /// Modes reported by the backend as supported.
  ///
  /// Mode semantics are platform-specific. In particular, application-window
  /// brightness is only distinct from system brightness on Android.
  final Set<ScreenBrightnessScope> supportedScopes;

  /// Whether brightness writes can only ever land on the primary display.
  ///
  /// The plugin exposes no display selector, so a secondary monitor cannot be
  /// addressed at all; this flag records that desktop writes are pinned to the
  /// built-in or main screen. Windows resolves `MonitorFromWindow(GetDesktopWindow(),
  /// MONITOR_DEFAULTTOPRIMARY)` and then drives the FIRST DDC-capable monitor
  /// under it (its failure text is literally "No compatible primary Windows
  /// monitor"); macOS targets `CGMainDisplayID()`; Linux keeps the single
  /// `/sys/class/backlight` node chosen by type priority and discards the rest.
  /// Android's application scope is genuinely per-window and phones and the
  /// browser have one screen, so the flag is false there.
  final bool targetsPrimaryDisplay;

  /// Whether writing global system brightness requires special permission.
  final bool requiresSystemPermission;

  /// Native backend name, useful for diagnostics (for example `sysfs` or
  /// `DXVA2`). This value is diagnostic, not a stable API for branching.
  final String backend;

  /// Whether the backend reports support for [scope].
  bool supportsScope(ScreenBrightnessScope scope) => supportedScopes.contains(scope);

  /// Whether a write operation should be offered by the UI.
  bool get canOfferBrightnessControl => canWrite && writeSupport != ScreenBrightnessWriteSupport.unsupported;
}

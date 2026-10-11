import 'package:live_platform/src/runtime/form_factor.dart';
import 'package:live_platform/src/runtime/platform_kind.dart';

/// What the current platform can do, resolved once at bootstrap from
/// per-platform defaults plus explicit overrides.
///
/// Defaults are conservative: an unknown platform claims nothing. The app
/// shell overrides any answer it knows better (e.g. tray support after a
/// successful window_manager init).
final class PlatformCapabilities {
  /// A capability set; see the per-platform factory for defaults.
  const new({
    required this.mediaSession,
    required this.pictureInPicture,
    required this.windowing,
    required this.systemTray,
    required this.filePicker,
  });

  /// Defaults per platform and form factor. TV builds claim no windowing
  /// and no tray; unknown platforms claim nothing.
  ///
  /// A factory on purpose (not a static method); the
  /// `unnecessary_type_name_in_constructor` lint cannot be satisfied for
  /// factories under the `new` shorthand, hence the ignore below.
  // ignore: unnecessary_type_name_in_constructor
  factory PlatformCapabilities.defaults({required PlatformKind kind, required FormFactor formFactor}) {
    if (kind == PlatformKind.unknown) {
      return PlatformCapabilities.none;
    }
    final desktop = switch (kind) {
      PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => true,
      _ => false,
    };
    final tv = formFactor == FormFactor.tv;
    return PlatformCapabilities(
      mediaSession: true,
      pictureInPicture: kind == PlatformKind.android && !tv,
      windowing: desktop,
      systemTray: desktop && !tv,
      filePicker: desktop || kind == PlatformKind.android || kind == PlatformKind.ios,
    );
  }

  /// The all-false set for unknown environments.
  static const PlatformCapabilities none = PlatformCapabilities(
    mediaSession: false,
    pictureInPicture: false,
    windowing: false,
    systemTray: false,
    filePicker: false,
  );

  /// System media session (SMTC / MPRIS / MediaSession).
  final bool mediaSession;

  /// System picture-in-picture.
  final bool pictureInPicture;

  /// Window-level features: unframed windows, snapshots, true fullscreen.
  final bool windowing;

  /// A system tray icon.
  final bool systemTray;

  /// A native file/dir picker (file_selector or equivalent).
  final bool filePicker;

  /// A copy with individual answers overridden by the app shell.
  PlatformCapabilities copyWith({
    bool? mediaSession,
    bool? pictureInPicture,
    bool? windowing,
    bool? systemTray,
    bool? filePicker,
  }) => PlatformCapabilities(
    mediaSession: mediaSession ?? this.mediaSession,
    pictureInPicture: pictureInPicture ?? this.pictureInPicture,
    windowing: windowing ?? this.windowing,
    systemTray: systemTray ?? this.systemTray,
    filePicker: filePicker ?? this.filePicker,
  );
}

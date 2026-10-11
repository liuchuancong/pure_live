import 'package:flutter/foundation.dart';

import 'package:live_uikit/src/core/ui_platform.dart';
import 'package:live_uikit/src/tokens/breakpoints.dart';

/// How a page is laid out, which is not the same question as which device
/// it runs on: a desktop window dragged narrow becomes [mobile]-shaped, a
/// TV stays [tv] whatever its size.
enum LiveLayoutMode {
  /// One column, bottom navigation, thumb-reachable controls.
  mobile,

  /// Side navigation, window-shaped content, pointer and keyboard.
  desktop,

  /// Large cards, focus navigation, remote-control reach.
  tv;

  /// Resolves the layout mode from the platform and the current width.
  ///
  /// A TV build always lays out as TV; otherwise the window's size class
  /// decides between [mobile] and [desktop] — the platform only supplies
  /// the breakpoints, so a narrow window on Windows really does get the
  /// mobile layout.
  static LiveLayoutMode resolve({
    required LiveUiPlatform platform,
    required double width,
    LiveBreakpoints breakpoints = const LiveBreakpoints(),
  }) {
    if (platform.isTv) {
      return LiveLayoutMode.tv;
    }
    if (platform.isDesktop || platform == LiveUiPlatform.web) {
      return width < breakpoints.desktop ? LiveLayoutMode.mobile : LiveLayoutMode.desktop;
    }
    return width < breakpoints.tablet ? LiveLayoutMode.mobile : LiveLayoutMode.desktop;
  }
}

/// The input devices the UI can assume are present.
///
/// A page that needs touch, a mouse, a keyboard or a remote checks these
/// sets instead of guessing from the platform: a Windows tablet has touch,
/// a TV has a remote and often a keyboard but no pointer, and a desktop
/// browser may well have a touch screen.
enum LiveInputMode {
  /// Finger taps and gestures.
  touch,

  /// Pointer hover, click and scroll wheel.
  mouse,

  /// Physical keyboard shortcuts and text entry.
  keyboard,

  /// D-pad, media keys and the TV back button.
  remote,
}

/// The input devices a platform ships with, as the environment's default.
extension LiveInputModeDefaults on LiveUiPlatform {
  /// The input devices this platform ships with in the common case.
  ///
  /// Used as the environment's starting point; the composition root may
  /// widen it (a desktop with a touch screen, a phone with a paired
  /// keyboard) once it has real device information.
  Set<LiveInputMode> get defaultInputModes => switch (this) {
    LiveUiPlatform.android => {LiveInputMode.touch, LiveInputMode.keyboard},
    LiveUiPlatform.ios => {LiveInputMode.touch},
    LiveUiPlatform.androidTv => {LiveInputMode.remote},
    LiveUiPlatform.windows ||
    LiveUiPlatform.macos ||
    LiveUiPlatform.linux ||
    LiveUiPlatform.web => {LiveInputMode.mouse, LiveInputMode.keyboard},
  };
}

/// The UI's runtime environment: facts about where the interface is being
/// rendered, gathered once by the composition root and read by the theme,
/// the background system and (later) the focus infrastructure.
///
/// The environment is deliberately data, not behaviour: no widget looks at
/// `Platform.isX`, and no page decides for itself whether it is on a TV.
@immutable
final class LiveUiEnvironment {
  /// An environment of the given facts.
  const new({
    required this.platform,
    required this.layoutMode,
    required this.inputModes,
    this.supportsBlur = true,
    this.supportsAnimations = true,
    this.systemTextScale = 1,
  });

  /// An environment for [platform] with that platform's defaults, laid out
  /// for [width].
  ///
  /// [supportsBlur] is false for TV builds by default: backdrop filters are
  /// the single most expensive visual effect on TV hardware.
  // The `new(...)` shorthand does not parse in factory bodies on the
  // current SDK, so the type name stays.
  // ignore: unnecessary_type_name_in_constructor
  factory LiveUiEnvironment.forPlatform({
    required LiveUiPlatform platform,
    required double width,
    Set<LiveInputMode>? inputModes,
    bool? supportsBlur,
    bool? supportsAnimations,
    double systemTextScale = 1,
    LiveBreakpoints breakpoints = const LiveBreakpoints(),
  }) => LiveUiEnvironment(
    platform: platform,
    layoutMode: LiveLayoutMode.resolve(platform: platform, width: width, breakpoints: breakpoints),
    inputModes: inputModes ?? platform.defaultInputModes,
    supportsBlur: supportsBlur ?? !platform.isTv,
    supportsAnimations: supportsAnimations ?? true,
    systemTextScale: systemTextScale,
  );

  /// Where the UI runs.
  final LiveUiPlatform platform;

  /// How pages lay out.
  final LiveLayoutMode layoutMode;

  /// Which input devices are present.
  final Set<LiveInputMode> inputModes;

  /// Whether backdrops may use blur; false on low-end and TV devices.
  final bool supportsBlur;

  /// Whether transitions and focus animations may run.
  final bool supportsAnimations;

  /// The platform's text scale, clamped by the app to a sane range.
  final double systemTextScale;

  /// Whether the UI must be operable without touch.
  bool get needsFocusNavigation => layoutMode == LiveLayoutMode.tv || !inputModes.contains(LiveInputMode.touch);

  /// The same environment with [layoutMode] replaced, for the responsive
  /// layout widgets that recompute it from the live window size.
  LiveUiEnvironment withLayoutMode(LiveLayoutMode mode) => LiveUiEnvironment(
    platform: platform,
    layoutMode: mode,
    inputModes: inputModes,
    supportsBlur: supportsBlur,
    supportsAnimations: supportsAnimations,
    systemTextScale: systemTextScale,
  );

  /// The same environment recomputed for a new window [width].
  LiveUiEnvironment withWidth(double width, {LiveBreakpoints breakpoints = const LiveBreakpoints()}) =>
      withLayoutMode(LiveLayoutMode.resolve(platform: platform, width: width, breakpoints: breakpoints));

  /// The same environment with [inputModes] widened, for a device the
  /// composition root knows has more than its platform's defaults.
  LiveUiEnvironment withInputModes(Set<LiveInputMode> modes) => LiveUiEnvironment(
    platform: platform,
    layoutMode: layoutMode,
    inputModes: modes,
    supportsBlur: supportsBlur,
    supportsAnimations: supportsAnimations,
    systemTextScale: systemTextScale,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LiveUiEnvironment &&
        other.platform == platform &&
        other.layoutMode == layoutMode &&
        other.supportsBlur == supportsBlur &&
        other.supportsAnimations == supportsAnimations &&
        other.systemTextScale == systemTextScale &&
        setEquals(other.inputModes, inputModes);
  }

  @override
  int get hashCode => Object.hash(
    platform,
    layoutMode,
    Object.hashAllUnordered(inputModes),
    supportsBlur,
    supportsAnimations,
    systemTextScale,
  );
}

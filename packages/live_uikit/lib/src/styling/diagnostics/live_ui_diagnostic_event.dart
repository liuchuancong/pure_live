import 'package:flutter/foundation.dart' show immutable;

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart' show LiveDesignLanguage;
import 'package:live_uikit/src/styling/contracts/live_ui_surfaces.dart' show LiveUiSurface;
import 'package:live_uikit/src/styling/diagnostics/live_ui_diagnostic_codes.dart';

/// The controls the resolver dispatches (§15.1). A stable identity so a
/// diagnostic and a capability declaration name the same control.
enum LiveUiControl {
  /// The button control.
  button,

  /// The card container.
  card,

  /// The text input.
  textField,

  /// The switch.
  switchWidget,

  /// The checkbox.
  checkbox,

  /// The slider.
  slider,

  /// The segmented control.
  segmented,

  /// The progress indicator.
  progress,

  /// The select dropdown.
  select,

  /// The tab bar.
  tabBar,

  /// The page frame (background, bars, floating action).
  scaffold,

  /// The top bar of a page.
  appBar,

  /// A tappable list row.
  listRow,

  /// The bottom navigation bar of a shell.
  navBar,

  /// A transient status message.
  toast,

  /// A modal message over the page — the dialog's own surface.
  dialog,

  /// The swipeable page switcher a tab bar drives.
  tabView,
}

/// An observable UI-runtime event, delivered to a host-supplied
/// `LiveUiDiagnosticSink` rather than a concrete logging package (§8.7).
///
/// What is observable now is what the *device* cannot afford. A language with no
/// adapter, a control its adapter cannot render and a surface it does not own are
/// raised as exceptions by the resolver instead: there is no shared renderer left
/// to fall back to, so those are faults, not downgrades to log.
@immutable
final class LiveUiDiagnostic {
  /// A diagnostic for [code] about [language].
  const new({required this.code, required this.language, this.control, this.surface});

  /// The reason it fired.
  final LiveUiDiagnosticCode code;

  /// The design language the diagnostic concerns.
  final LiveDesignLanguage language;

  /// The control the diagnostic concerns, or null when it concerns the
  /// environment or the whole language.
  final LiveUiControl? control;

  /// The structural surface the diagnostic concerns — the app host or the shell —
  /// or null unless it is structural.
  final LiveUiSurface? surface;

  @override
  String toString() {
    final detail = switch ((control, surface)) {
      (final LiveUiControl named, _) => ', ${named.name}',
      (_, final LiveUiSurface named) => ', ${named.name}',
      (null, null) => '',
    };
    return 'LiveUiDiagnostic(${code.name}, ${language.name}$detail)';
  }
}

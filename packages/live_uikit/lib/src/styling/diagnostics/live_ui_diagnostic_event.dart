import 'package:flutter/foundation.dart' show immutable;

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart' show LiveDesignLanguage;
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
}

/// How a control is rendered for the active design language (§15.2).
enum LiveImplementationKind {
  /// A dedicated, registered adapter's native widget.
  adapterNative,

  /// The shared token renderer — the language has no registered adapter, or
  /// the adapter does not declare this control.
  shared,

  /// An application-registered override for this control (combination root).
  custom,
}

/// An observable UI-runtime event, delivered to a host-supplied
/// `LiveUiDiagnosticSink` rather than a concrete logging package (§8.7).
///
/// Carries the language, the control (null for a language- or environment-wide
/// downgrade), the resolved [kind] and the [code], so a test can assert "this
/// control, in this style, was rendered by that implementation for this reason"
/// (§15.6).
@immutable
final class LiveUiDiagnostic {
  /// A diagnostic for [code] about [language].
  const new({required this.code, required this.language, this.control, this.kind = LiveImplementationKind.shared});

  /// The reason it fired.
  final LiveUiDiagnosticCode code;

  /// The design language the diagnostic concerns.
  final LiveDesignLanguage language;

  /// The control the diagnostic concerns, or null when the downgrade is
  /// language-wide (no adapter) or environment-wide (no effect).
  final LiveUiControl? control;

  /// The implementation the control fell back to, so the host can see the
  /// downgrade target rather than only that one happened.
  final LiveImplementationKind kind;

  @override
  String toString() =>
      'LiveUiDiagnostic(${code.name}, ${language.name}'
      '${control == null ? '' : ', ${control!.name}'}, -> ${kind.name})';
}

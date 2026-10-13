import 'package:live_uikit/src/styling/diagnostics/live_ui_diagnostic_event.dart';

/// A receiver of [LiveUiDiagnostic]s; the application wires it to its own
/// logging/diagnostics sink. Kept as a plain function so the core depends on no
/// logging implementation (§3.10: no Talker or other concrete logger).
typedef LiveUiDiagnosticSink = void Function(LiveUiDiagnostic diagnostic);

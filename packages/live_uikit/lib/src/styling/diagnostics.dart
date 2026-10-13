/// UI-runtime diagnostics (§3.10/§10.15/§15).
///
/// The core defines the diagnostic *events* and the *sink* interface only; it
/// binds no logger and prints nothing itself. The application wires a
/// `LiveUiDiagnosticSink` to its own logging so every
/// downgrade — an unregistered language, an unsupported control, an effect the
/// device cannot afford — is observable rather than silent (§8.10).
library;

export 'diagnostics/live_ui_diagnostic_codes.dart';
export 'diagnostics/live_ui_diagnostic_event.dart';
export 'diagnostics/live_ui_diagnostic_sink.dart';

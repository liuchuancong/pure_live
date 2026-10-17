/// Why a UI-runtime diagnostic fired (§3.10/§7/§15.3).
///
/// Only one reason is left: what the device cannot afford. A language with no
/// adapter, a control its adapter cannot render and a surface it does not own
/// are no longer downgrades to report — they are faults the resolver raises,
/// because there is no shared renderer standing underneath to make them look
/// like a working UI.
enum LiveUiDiagnosticCode {
  /// The environment cannot afford an effect (blur, TV focus, backdrop
  /// filter), so a verified degraded visual stands in (§15.3 tail).
  unsupportedEffect,
}

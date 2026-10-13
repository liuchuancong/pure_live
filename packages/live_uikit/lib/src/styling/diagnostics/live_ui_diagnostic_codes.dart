/// Why a UI-runtime diagnostic fired (§3.10/§7/§15.3).
///
/// Every value names one branch of the `LiveUiResolver`'s decision flow, so a
/// host can tell apart "the language has no adapter" from "the adapter cannot
/// render this control" from "the device cannot afford this effect". No
/// downgrade happens without one of these codes being reported (§8.10).
enum LiveUiDiagnosticCode {
  /// The selected language has no registered adapter, so controls resolve to
  /// the shared token renderer. Reported once per language change.
  adapterMissing,

  /// The registry cannot even supply its shared fallback for the default
  /// language — a startup-level fault (§7), never recovered silently.
  defaultAdapterMissing,

  /// The registered adapter does not declare this control, so it resolves to
  /// the shared implementation for just that control (§15.3 step 2b).
  controlUnsupported,

  /// The environment cannot afford an effect (blur, TV focus, backdrop
  /// filter), so a verified degraded visual stands in (§15.3 tail).
  unsupportedEffect,
}

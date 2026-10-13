/// Fluent design-language adapter for `live_uikit`.
///
/// Public entry exposes only the registration API (§6): the adapter type and
/// its Fluent delegates are reached through here, not imported directly, so
/// business code depends on the core contract rather than this package.
library;

export 'package:live_uikit_fluent/src/adapter/fluent_ui_registration.dart';

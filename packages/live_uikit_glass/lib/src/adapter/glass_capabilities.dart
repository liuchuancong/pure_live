import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_glass` renders with native `glass_morphism_plus`
/// widgets (§3.1 / §7). Everything else falls back to the core shared token
/// renderer; keep in sync with the methods `GlassLanguageAdapter` overrides (§17).
const LiveUiCapabilities glassCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
});

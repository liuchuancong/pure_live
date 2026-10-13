import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/src/adapter/glass_ui_adapter.dart';

/// The stable runtime id for the Glass adapter.
const String glassUiAdapterId = 'glass';

/// The Glass adapter instance for the composition root to register.
const LanguageAdapter glassUiAdapter = GlassLanguageAdapter();

/// Creates the Glass adapter for the application composition root to register
/// into the core [LanguageRegistry].
LanguageAdapter createGlassUiAdapter() => const GlassLanguageAdapter();

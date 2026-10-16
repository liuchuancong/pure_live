import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/src/adapter/glass_adapter.dart';

/// The stable runtime id for the Glass adapter.
const String glassAdapterId = 'glass';

/// The Glass adapter instance for the composition root to register.
const LanguageAdapter glassAdapter = GlassLanguageAdapter();

/// Creates the Glass adapter for the application composition root to register
/// into the core [LanguageRegistry].
LanguageAdapter createGlassAdapter() => const GlassLanguageAdapter();

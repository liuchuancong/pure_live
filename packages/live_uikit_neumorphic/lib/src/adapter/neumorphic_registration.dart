import 'package:live_uikit/styling.dart';
import 'package:live_uikit_neumorphic/src/adapter/neumorphic_adapter.dart';

/// The stable runtime id for the Neumorphic adapter.
const String neumorphicAdapterId = 'neumorphic';

/// The Neumorphic adapter instance for the composition root to register.
const LanguageAdapter neumorphicAdapter = NeumorphicLanguageAdapter();

/// Creates the Neumorphic adapter for the application composition root to
/// register into the core [LanguageRegistry].
LanguageAdapter createNeumorphicAdapter() => const NeumorphicLanguageAdapter();

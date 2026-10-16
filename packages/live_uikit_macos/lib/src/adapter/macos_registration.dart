import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/src/adapter/macos_adapter.dart';

/// The stable runtime id for the macOS adapter.
const String macosAdapterId = 'macos';

/// The macOS adapter instance for the composition root to register.
const LanguageAdapter macosAdapter = MacosLanguageAdapter();

/// Creates the macOS adapter for the application composition root to register
/// into the core [LanguageRegistry].
LanguageAdapter createMacosAdapter() => const MacosLanguageAdapter();

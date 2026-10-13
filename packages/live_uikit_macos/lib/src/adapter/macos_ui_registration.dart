import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/src/adapter/macos_ui_adapter.dart';

/// The stable runtime id for the macOS adapter.
const String macosUiAdapterId = 'macos';

/// The macOS adapter instance for the composition root to register.
const LanguageAdapter macosUiAdapter = MacosLanguageAdapter();

/// Creates the macOS adapter for the application composition root to register
/// into the core [LanguageRegistry].
LanguageAdapter createMacosUiAdapter() => const MacosLanguageAdapter();

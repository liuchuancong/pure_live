import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/src/adapter/wind_adapter.dart';

/// The stable runtime id for the Wind adapter.
const String windAdapterId = 'wind';

/// The Wind adapter instance for the composition root to register.
const LanguageAdapter windAdapter = WindLanguageAdapter();

/// Creates the Wind adapter for the application composition root to register
/// into the core [LanguageRegistry].
LanguageAdapter createWindAdapter() => const WindLanguageAdapter();

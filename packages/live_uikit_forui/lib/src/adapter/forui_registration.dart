import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/src/adapter/forui_adapter.dart';

/// The stable runtime id for the ForUI adapter.
const String foruiAdapterId = 'forui';

/// The ForUI adapter instance for the composition root to register.
const LanguageAdapter foruiAdapter = ForuiLanguageAdapter();

/// Localization delegates forUI widgets require; append to the core's
/// `liveLocalizationsDelegates` in the app's `MaterialApp`. forui labels several
/// controls through `LocalizedText` (and supports Material's 115 languages), so a host
/// that omits this delegate gets the library's assertion instead of a translated
/// control.
const List<LocalizationsDelegate<dynamic>> foruiLocalizationsDelegates = [forui.FLocalizations.delegate];

/// Creates the ForUI adapter for the application composition root to register into the
/// core [LanguageRegistry]. The adapter never self-registers.
LanguageAdapter createForuiAdapter() => const ForuiLanguageAdapter();

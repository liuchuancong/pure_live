import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_fluent/src/adapter/fluent_ui_adapter.dart';

/// The stable runtime id for the Fluent adapter.
const String fluentUiAdapterId = 'fluent';

/// The Fluent adapter instance for the composition root to register.
const LanguageAdapter fluentUiAdapter = FluentLanguageAdapter();

/// Localization delegates fluent widgets require; append to the core's
/// `liveLocalizationsDelegates` in the app's `MaterialApp`.
const List<LocalizationsDelegate<dynamic>> fluentLocalizationsDelegates = [fluent.FluentLocalizations.delegate];

/// Creates the Fluent adapter for the application composition root to register
/// into the core [LanguageRegistry]. The adapter never self-registers.
LanguageAdapter createFluentUiAdapter() => const FluentLanguageAdapter();

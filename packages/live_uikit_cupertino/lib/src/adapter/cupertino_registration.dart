import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_adapter.dart';

/// The stable runtime id for the Cupertino UI adapter.
const String cupertinoAdapterId = 'cupertino';

/// The adapter instance for the composition root to register.
const LanguageAdapter cupertinoAdapter = CupertinoLanguageAdapter();

/// Localization delegates `cupertino_ui` widgets require (its own Cupertino
/// localizations, distinct from Flutter's); append to the core's
/// `liveLocalizationsDelegates` in the app's `MaterialApp`.
const List<LocalizationsDelegate<dynamic>> cupertinoLocalizationsDelegates = [cu.GlobalCupertinoLocalizations.delegate];

/// Creates the adapter for the application composition root to register.
LanguageAdapter createCupertinoAdapter() => const CupertinoLanguageAdapter();

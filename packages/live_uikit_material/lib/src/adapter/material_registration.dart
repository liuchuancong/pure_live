import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/src/adapter/material_adapter.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// The stable runtime id for the Material UI adapter.
const String materialAdapterId = 'material';

/// The adapter instance for the composition root to register.
const LanguageAdapter materialAdapter = MaterialLanguageAdapter();

/// Localization delegates `material_ui` widgets require (its own Material
/// localizations); append to the core's `liveLocalizationsDelegates` in the
/// app's `MaterialApp`.
const List<LocalizationsDelegate<dynamic>> materialLocalizationsDelegates = [mu.GlobalMaterialLocalizations.delegate];

/// Creates the adapter for the application composition root to register.
LanguageAdapter createMaterialAdapter() => const MaterialLanguageAdapter();

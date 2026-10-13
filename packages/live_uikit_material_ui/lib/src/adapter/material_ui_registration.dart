import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/src/adapter/material_ui_adapter.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// The stable runtime id for the Material UI adapter.
const String materialUiAdapterId = 'materialUi';

/// The adapter instance for the composition root to register.
const LanguageAdapter materialUiAdapter = MaterialUiLanguageAdapter();

/// Localization delegates `material_ui` widgets require (its own Material
/// localizations); append to the core's `liveLocalizationsDelegates` in the
/// app's `MaterialApp`.
const List<LocalizationsDelegate<dynamic>> materialUiLocalizationsDelegates = [mu.GlobalMaterialLocalizations.delegate];

/// Creates the adapter for the application composition root to register.
LanguageAdapter createMaterialUiAdapter() => const MaterialUiLanguageAdapter();

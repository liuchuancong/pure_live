import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:flutter_localizations/flutter_localizations.dart';

/// The localization delegates the core UI itself needs, in one const list.
///
/// Material and macOS controls look up `MaterialLocalizations` (macOS also
/// `CupertinoLocalizations`); Cupertino controls look up `CupertinoLocalizations`.
/// A host app drops this into `MaterialApp.localizationsDelegates`. Delegates
/// for a specific adapter (e.g. `FluentLocalizations`) live in that adapter's
/// own package and are appended by the composition root, so the core never
/// depends on a third-party UI library.
///
/// `supportedLocales` must include a locale every active delegate covers —
/// English is the safe common denominator; delegates fall back to it otherwise.
const List<LocalizationsDelegate<dynamic>> liveLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

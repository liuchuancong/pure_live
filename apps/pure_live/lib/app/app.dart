import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_uikit/styling.dart' show LiveApp;

import 'package:pure_live/app/delegates.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/theme/app_theme.dart';
import 'package:pure_live/l10n/generated/strings.g.dart' show TranslationProvider, t;

/// The root widget: the app host the chosen design language ships.
///
/// [AppTheme] sits above this and turns the persisted appearance into a
/// `LiveTheme`; this hands the router to that language's own app widget —
/// `FluentApp`, `MacosApp`, the `material_ui` fork's `MaterialApp`, the
/// `cupertino_ui` fork's `CupertinoApp`, and the token Material host for the
/// languages whose library ships none.
///
/// The host is not a detail: it owns the route transition, the overlay a dialog
/// or a text-selection toolbar opens into, the scroll physics and the chrome's
/// own strings. Keeping a single `MaterialApp` at the bottom is what made every
/// language look like Material no matter which controls were drawn above it.
final class PureLiveApp extends ConsumerWidget {
  /// The application root.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LiveApp(
    routerConfig: ref.watch(routerProvider),
    onGenerateTitle: (context) => t.app.title,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    locale: appFlutterLocale,
    builder: (context, child) => TranslationProvider(child: child!),
  );
}

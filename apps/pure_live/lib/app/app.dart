import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_uikit/styling.dart' show UiBrightnessMode;

import 'package:pure_live/app/delegates.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/theme/app_theme.dart';
import 'package:pure_live/l10n/generated/strings.g.dart' show TranslationProvider, t;

/// The root widget: the material host the router lives in.
///
/// The real skin comes from `LiveTheme` — [AppTheme] sits above this widget
/// and every page reads the `Live*` components — so what remains here is the
/// chrome material itself still owns: text selection, tooltips, dialogs, the
/// route transition background, seeded from the same accent and brightness
/// the user picked.
final class PureLiveApp extends ConsumerWidget {
  /// The application root.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(uiConfigProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => t.app.title,
      theme: materialThemeSeed(config, Brightness.light),
      darkTheme: materialThemeSeed(config, Brightness.dark),
      themeMode: switch (config.brightness) {
        UiBrightnessMode.system => ThemeMode.system,
        UiBrightnessMode.light => ThemeMode.light,
        UiBrightnessMode.dark => ThemeMode.dark,
      },
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      locale: appFlutterLocale,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => TranslationProvider(child: child!),
    );
  }
}

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalCupertinoLocalizations, GlobalMaterialLocalizations, GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/localization/locale_controller.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/theme/app_theme_controller.dart';
import 'package:pure_live/i18n/translations.g.dart';

/// The root widget: `DsApp`, the app root `desen_ui` ships.
///
/// The theme pair (light and dark) is built once at start-up from the same
/// accent; the mode only picks between them. `DsApp` wires `DsScope`, the
/// page route and the scroll behaviour, so nothing Material-specific is
/// needed above the pages.
final class PureLiveApp extends ConsumerWidget {
  /// The application root.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(activeLocaleProvider);
    final router = ref.watch(routerProvider);
    return DsApp.router(
      onGenerateTitle: (context) => context.t.app.title,
      theme: ref.watch(dsThemeProvider(Brightness.light)),
      darkTheme: ref.watch(dsThemeProvider(Brightness.dark)),
      themeMode: mode,
      locale: flutterLocaleOf(locale),
      supportedLocales: AppLocale.values.map(flutterLocaleOf),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

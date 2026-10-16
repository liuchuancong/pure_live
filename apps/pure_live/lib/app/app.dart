import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/adapters/design_language_registry.dart';
import 'package:pure_live/app/delegates.dart';
import 'package:pure_live/app/providers/app_providers.dart';
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
///
/// What that language actually gets is recorded on every debug build: the
/// diagnostics [AppTheme] carries say when a language fell back, and this says
/// what was chosen in the first place, so "I switched the style and nothing
/// changed" is answerable from the log instead of by guessing whether the library
/// behind that entry ships an app widget at all.
final class PureLiveApp extends ConsumerWidget {
  /// The application root.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(uiConfigProvider);
    final adapter = appLanguageRegistry.adapterFor(config.language);
    if (kDebugMode) {
      debugPrint(
        '[ui] language=${config.language.name} adapter=${adapter.id} '
        'host=${_surface(adapter, LiveUiSurface.appHost)} '
        'shell=${_surface(adapter, LiveUiSurface.appShell)}',
      );
    }
    return LiveApp(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => t.app.title,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      locale: appFlutterLocale,
      builder: (context, child) => TranslationProvider(child: child!),
    );
  }

  /// Names the surface, with the token fallback marked — a language that owns
  /// neither surface still renders a window, just not one of its library's.
  static String _surface(LanguageAdapter adapter, LiveUiSurface surface) =>
      adapter.surfaces.supports(surface) ? surface.name : '${surface.name}->token';
}

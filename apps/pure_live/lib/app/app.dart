import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/delegates.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/shell/desktop_title_frame.dart' show DesktopTitleFrame;
import 'package:pure_live/app/theme/app_theme.dart';
import 'package:pure_live/features/wallpaper/wallpaper_background_layer.dart';
import 'package:pure_live/l10n/generated/strings.g.dart' show TranslationProvider, t;
import 'package:pure_live/platforms/desktop/shell/window_frame_edge.dart' show WindowFrameEdge;
import 'package:pure_uikit/pure_uikit.dart';

/// The root widget: the app host the chosen design language ships.
///
/// [AppTheme] sits above this and turns the persisted appearance into a
/// `PureTheme`; this hands the router to that language's own app widget —
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
    return PureApp(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => t.app.title,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      locale: appFlutterLocale,
      // The preferences host mounts the timers the app runs on its own
      // behalf: the countdown close and the lifecycle feed the list pages'
      // refresh-on-resume reads. The wallpaper layer sits inside it, once,
      // painting the chosen background behind every route.
      // The frame edge is the outermost thing Flutter paints: it sits on the
      // window's own boundary, over the wallpaper layer, and it is a Windows
      // concern rather than a route concern, so it belongs here and not in any
      // scaffold. See WindowFrameEdge for why the app has to draw it at all.
      // Inside it rides the caption strip (the reference's `DesktopFrame`):
      // one strip above the whole navigator, so every route — a pushed room,
      // settings, search — keeps its drag band and window buttons, not just
      // the home tabs the shell used to be the only thing under a bar.
      builder: (context, child) => WindowFrameEdge(
        child: AppPreferencesHost(
          child: TranslationProvider(
            child: DesktopTitleFrame(child: WallpaperBackgroundLayer(child: child!)),
          ),
        ),
      ),
    );
  }
}

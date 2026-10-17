import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/src/theme/forui_theme_builder.dart';

/// Builds a ForUI application host from a [LanguageHostSpec] (§ surfaces).
///
/// forui ships no application widget — the library is a theme and a set of
/// components, and nothing in it owns a route, a title or a locale — so this
/// adapter hosts the app itself, on Flutter's own `WidgetsApp` with the library's
/// theme installed above the routed tree. `WidgetsApp` is what keeps the language
/// honest: a `MaterialApp` would hand the page transitions, the scroll physics and
/// the dialog barrier to Material no matter which controls are drawn above them,
/// and `WidgetsApp` hands none of that to Material either.
///
/// [LanguageHostSpec.localizationsDelegates] carries what the app needs from
/// here: with no Material application widget above, the labels and text
/// behaviours forui's own widgets ask for have to arrive through that list, and
/// the composition root installs them for every language up front.
abstract final class ForuiHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = ForuiThemeBuilder.build(LiveTheme.of(context).token);
    return WidgetsApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      // The theme is the outermost thing inside the app so a route's own
      // overlay content resolves it too; the caller's builder — the ink surface
      // and the translation scope — stays inside it.
      builder: (context, child) => forui.FTheme(
        data: theme,
        // The app widget hands its builder a child it has not built yet when the
        // router has nothing to show; the theme scope still has to wrap
        // something.
        child: spec.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      // `WidgetsApp` asks for one colour outright; it is the token's accent, so
      // the host's own chrome (a scrollbar thumb, a selection) is on-theme even
      // where no forui widget paints it.
      color: LiveTheme.of(context).colors.primary,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/src/theme/neumorphic_theme_builder.dart';

/// Builds a Neumorphic application host from a [LanguageHostSpec] (§ surfaces).
///
/// **Composed, and composed of this library's theme plus Flutter's own app widget.**
/// `flutter_neumorphic_ui_kit` ships no application widget — the library is a
/// theme (`NeuTheme`) plus a set of components, and nothing in it owns a route,
/// a title or a locale — so the host is Flutter's own `WidgetsApp` with the
/// library's theme installed above the routed tree. That is still a real host
/// and not a stand-in: a `MaterialApp` host would hand the page transitions, the scroll physics and the dialog barrier
/// to Material no matter which controls are drawn above them, and `WidgetsApp`
/// hands none of that to Material. A Neumorphic route now slides, scrolls
/// and dims its barrier on the host's own terms instead of Material's, and no
/// `MaterialApp` stands in.
///
/// [LanguageHostSpec.localizationsDelegates] carries what the app needs from
/// here: with no Material application widget above, the chrome strings and text
/// behaviours are supplied through that list, and the composition root installs
/// them for every language up front.
abstract final class NeumorphicHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = NeumorphicThemeBuilder.build(LiveTheme.of(context).token);
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
      builder: (context, child) => neu.NeuTheme(
        data: theme,
        // The app widget hands its builder a child it has not built yet when the
        // router has nothing to show; the theme scope still has to wrap
        // something.
        child: spec.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      // `WidgetsApp` asks for one colour outright; it is the token's accent, so
      // the host's own chrome (a scrollbar thumb, a selection) is on-theme even
      // where no Neumorphic widget paints it.
      color: LiveTheme.of(context).colors.primary,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}

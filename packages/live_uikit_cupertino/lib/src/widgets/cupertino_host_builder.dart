import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_builder.dart';

/// Builds the Cupertino UI app host from a [LanguageHostSpec] (§9 app host).
///
/// The fork ships its own `CupertinoApp`, and it is the only thing that gives a
/// Cupertino page its iOS behaviour: the slide-from-right route, the swipe-back
/// gesture, the scroll physics and the text-selection toolbar. A Material host
/// draws those Material, and no amount of native bars fixes the feel.
///
/// `CupertinoApp` takes one theme rather than a light and a dark slot, which
/// suits the token: the resolved theme already carries the chosen brightness.
abstract final class CupertinoHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) => cu.CupertinoApp.router(
    routerConfig: spec.routerConfig,
    title: spec.title,
    onGenerateTitle: spec.onGenerateTitle,
    localizationsDelegates: spec.localizationsDelegates,
    supportedLocales: spec.supportedLocales,
    locale: spec.locale,
    builder: spec.builder,
    theme: CupertinoThemeBuilder.build(LiveTheme.of(context).token),
    debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
  );
}

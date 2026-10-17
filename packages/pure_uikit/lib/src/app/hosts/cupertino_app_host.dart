import 'package:flutter/cupertino.dart' as cupertino;
import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:pure_uikit/src/styling/adapters/cupertino_theme_adapter.dart';

/// The Cupertino host: `CupertinoApp.router` is the only thing that gives a
/// Cupertino page its iOS behaviour — the slide-from-right route, the
/// swipe-back gesture, the scroll physics and the text-selection toolbar. It
/// takes one theme rather than a light and a dark slot, which suits the
/// binding: the resolved theme already carries the chosen brightness.
cupertino.CupertinoApp buildCupertinoAppHost(PureAppHostBinding b) {
  return cupertino.CupertinoApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: b.builder,
    theme: const CupertinoThemeAdapter().resolve(b.theme),
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The app's content types: one shell, one navigation per type. The app
/// switcher ("Pure Live" at the sidebar's head) lists them; choosing one
/// swaps the sidebar's business menu and the content area for that type's
/// own — the window and its chrome stay.
enum AppModule {
  /// Live streaming: the first module, the one every other waits on.
  live(DsIcons.tv, Color(0xFF0B84F3)),

  /// IPTV: channels, the guide and the channel library.
  iptv(DsIcons.antenna, Color(0xFF7C5CFC)),

  /// Video on demand (bilibili and friends).
  vod(DsIcons.film, Color(0xFFFB7299)),

  /// The music module.
  music(DsIcons.music, Color(0xFFFF9F2E));

  AppModule(this.icon, this.tile);

  /// The module's icon.
  final DsIconData icon;

  /// The tint of the module's icon tile in the app switcher.
  final Color tile;

  /// The module's localized name.
  String label(Translations t) => switch (this) {
    AppModule.live => t.common.moduleLive,
    AppModule.iptv => t.common.moduleIptv,
    AppModule.vod => t.common.moduleVod,
    AppModule.music => t.common.moduleMusic,
  };
}

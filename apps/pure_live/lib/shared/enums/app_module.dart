import 'package:desen_ui/desen_ui.dart';
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The app's content modes: one shell, one navigation per mode. Clicking a
/// module's icon swaps the sidebar's destinations and the mobile bottom
/// bar for that module's own; the window and its chrome stay.
enum AppModule {
  /// Live streaming: the first module, the one every other waits on.
  live(DsIcons.tv),

  /// IPTV: channels, the guide and the channel library.
  iptv(DsIcons.antenna),

  /// Video on demand (bilibili and friends).
  vod(DsIcons.film),

  /// The music module.
  music(DsIcons.music);

  AppModule(this.icon);

  /// The module's icon.
  final DsIconData icon;

  /// The module's localized name.
  String label(Translations t) => switch (this) {
    AppModule.live => t.common.moduleLive,
    AppModule.iptv => t.common.moduleIptv,
    AppModule.vod => t.common.moduleVod,
    AppModule.music => t.common.moduleMusic,
  };
}

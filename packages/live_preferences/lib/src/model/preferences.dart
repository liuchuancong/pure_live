import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_preferences/src/model/appearance_preferences.dart';
import 'package:live_preferences/src/model/danmaku_preferences.dart';
import 'package:live_preferences/src/model/desktop_preferences.dart';
import 'package:live_preferences/src/model/iptv_preferences.dart';
import 'package:live_preferences/src/model/library_preferences.dart';
import 'package:live_preferences/src/model/playback_preferences.dart';
import 'package:live_preferences/src/model/tv_preferences.dart';
import 'package:live_preferences/src/model/window_preferences.dart';

part 'preferences.freezed.dart';

/// The storage keys of the preference documents.
///
/// Each group is one document, versioned in its key: a group whose shape
/// changes gets `.v2` and a migration that reads the old key, so a broken
/// or outdated document only ever resets its own group and never the rest
/// of the user's settings.
abstract final class PreferencesKeys {
  /// The box the preference group documents live in.
  static const String box = 'settings.preferences';

  /// The group key prefix, also the export filename prefix.
  static const String prefix = 'preferences';

  /// Playback group key.
  static const String playback = '$prefix.playback.v1';

  /// Danmaku group key.
  static const String danmaku = '$prefix.danmaku.v1';

  /// Library group key.
  static const String library = '$prefix.library.v1';

  /// TV navigation group key.
  static const String tv = '$prefix.tv.v1';

  /// Floating window group key.
  static const String window = '$prefix.window.v1';

  /// Appearance group key.
  static const String appearance = '$prefix.appearance.v1';

  /// IPTV library group key.
  static const String iptv = '$prefix.iptv.v1';

  /// Desktop shell group key.
  static const String desktop = '$prefix.desktop.v1';

  /// Every group key, in document order.
  static const List<String> all = [playback, danmaku, library, tv, window, appearance, iptv, desktop];
}

/// The user's preferences, grouped by what they configure.
///
/// The root is a plain composition of independent groups: business packages
/// take the group they care about (the playback session takes
/// [playback], the danmaku renderer [danmaku]) and never reach into the
/// root, so a group can grow without any other package noticing.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class Preferences with _$Preferences {
  /// Preferences with the shipping defaults everywhere.
  const factory Preferences({
    /// Playback: quality, engine, line, recovery.
    @Default(PlaybackPreferences()) PlaybackPreferences playback,

    /// Danmaku: on/off, opacity, size, display area.
    @Default(DanmakuPreferences()) DanmakuPreferences danmaku,

    /// Library: list layout and history bounds.
    @Default(LibraryPreferences()) LibraryPreferences library,

    /// TV navigation: focus behaviour.
    @Default(TvPreferences()) TvPreferences tv,

    /// Floating window behaviour.
    @Default(WindowPreferences()) WindowPreferences window,

    /// Appearance: design language, theme mode, accent.
    @Default(AppearancePreferences()) AppearancePreferences appearance,

    /// IPTV: how the channel library and its guides go stale.
    @Default(IptvPreferences()) IptvPreferences iptv,

    /// Desktop shell: close button, tray, sign-in, rendering fallbacks.
    @Default(DesktopPreferences()) DesktopPreferences desktop,
  }) = _Preferences;

  /// The shipping defaults, for first start and for reset.
  static const Preferences defaults = Preferences();
}

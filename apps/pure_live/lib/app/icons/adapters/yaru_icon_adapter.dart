import 'package:flutter/material.dart' show Icons;
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconGlyph, PureIconMapping;

/// The Ubuntu skin's answers: pure Flutter glyphs.
///
/// The skin's own icon font (`yaru`'s YaruIcons) retired with the
/// dependency, so the table draws from Flutter's bundled Material face —
/// the outlined set, closest to Yaru's line weight. Keys it does not name
/// fall through to the global Lucide backstop, as before.
const PureIconMapping yaruIconsOverrides = PureIconMapping({
  AppIconKey.refresh: PureIconGlyph(Icons.refresh),
  AppIconKey.settings: PureIconGlyph(Icons.settings_outlined),
  AppIconKey.search: PureIconGlyph(Icons.search),
  AppIconKey.language: PureIconGlyph(Icons.language),
  AppIconKey.visibility: PureIconGlyph(Icons.visibility_outlined),
  AppIconKey.video: PureIconGlyph(Icons.videocam_outlined),
  AppIconKey.history: PureIconGlyph(Icons.history),
  AppIconKey.timer: PureIconGlyph(Icons.timer_outlined),
  AppIconKey.folder: PureIconGlyph(Icons.folder_outlined),
  AppIconKey.folderOpen: PureIconGlyph(Icons.folder_open_outlined),
  AppIconKey.download: PureIconGlyph(Icons.download_outlined),
  AppIconKey.bookmark: PureIconGlyph(Icons.bookmark_outlined),
  AppIconKey.delete: PureIconGlyph(Icons.delete_outline),
  AppIconKey.tag: PureIconGlyph(Icons.sell_outlined),
});

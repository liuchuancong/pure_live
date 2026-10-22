import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconGlyph, PureIconMapping;
import 'package:yaru/icons.dart' show YaruIcons;

/// The Ubuntu skin's answers: the `yaru` package's own icon font.
///
/// Names were checked against yaru-11's generated icon data; keys it does
/// not name fall through to the global Material backstop.
const PureIconMapping yaruIconsOverrides = PureIconMapping({
  AppIconKey.refresh: PureIconGlyph(YaruIcons.refresh),
  AppIconKey.settings: PureIconGlyph(YaruIcons.settings),
  AppIconKey.search: PureIconGlyph(YaruIcons.search),
  AppIconKey.language: PureIconGlyph(YaruIcons.globe),
  AppIconKey.visibility: PureIconGlyph(YaruIcons.eye),
  AppIconKey.video: PureIconGlyph(YaruIcons.video),
  AppIconKey.history: PureIconGlyph(YaruIcons.history),
  AppIconKey.timer: PureIconGlyph(YaruIcons.clock),
  AppIconKey.folder: PureIconGlyph(YaruIcons.folder),
  AppIconKey.folderOpen: PureIconGlyph(YaruIcons.folder_open_filled),
  AppIconKey.download: PureIconGlyph(YaruIcons.download),
  AppIconKey.bookmark: PureIconGlyph(YaruIcons.bookmark),
  AppIconKey.delete: PureIconGlyph(YaruIcons.trash),
  AppIconKey.tag: PureIconGlyph(YaruIcons.tag),
});

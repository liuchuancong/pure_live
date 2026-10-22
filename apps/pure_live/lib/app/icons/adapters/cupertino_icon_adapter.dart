import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconGlyph, PureIconMapping;

/// The iOS skin's answers: SF Symbols as shipped by `cupertino_icons`.
///
/// Only keys whose SF name was checked against the SDK's `CupertinoIcons`
/// are listed; anything else falls through to the global Material backstop.
const PureIconMapping cupertinoIconsOverrides = PureIconMapping({
  AppIconKey.refresh: PureIconGlyph(CupertinoIcons.arrow_clockwise),
  AppIconKey.back: PureIconGlyph(CupertinoIcons.chevron_left),
  AppIconKey.chevronRight: PureIconGlyph(CupertinoIcons.chevron_right),
  AppIconKey.more: PureIconGlyph(CupertinoIcons.ellipsis_circle),
  AppIconKey.settings: PureIconGlyph(CupertinoIcons.gear),
  AppIconKey.search: PureIconGlyph(CupertinoIcons.search),
  AppIconKey.close: PureIconGlyph(CupertinoIcons.xmark),
  AppIconKey.openExternal: PureIconGlyph(CupertinoIcons.arrow_up_left),
  AppIconKey.link: PureIconGlyph(CupertinoIcons.link),
  AppIconKey.language: PureIconGlyph(CupertinoIcons.globe),
  AppIconKey.live: PureIconGlyph(CupertinoIcons.film),
  AppIconKey.follow: PureIconGlyph(CupertinoIcons.heart),
  AppIconKey.followed: PureIconGlyph(CupertinoIcons.heart_fill),
  AppIconKey.bookmark: PureIconGlyph(CupertinoIcons.bookmark),
  AppIconKey.timer: PureIconGlyph(CupertinoIcons.timer),
  AppIconKey.info: PureIconGlyph(CupertinoIcons.info_circle),
  AppIconKey.error: PureIconGlyph(CupertinoIcons.exclamationmark_circle),
  AppIconKey.blocked: PureIconGlyph(CupertinoIcons.slash_circle),
  AppIconKey.check: PureIconGlyph(CupertinoIcons.checkmark),
  AppIconKey.visibility: PureIconGlyph(CupertinoIcons.eye),
  AppIconKey.hidden: PureIconGlyph(CupertinoIcons.eye_slash),
  AppIconKey.play: PureIconGlyph(CupertinoIcons.play_fill),
  AppIconKey.pause: PureIconGlyph(CupertinoIcons.pause_fill),
  AppIconKey.video: PureIconGlyph(CupertinoIcons.camera),
  AppIconKey.volumeHigh: PureIconGlyph(CupertinoIcons.speaker_2),
  AppIconKey.volumeMute: PureIconGlyph(CupertinoIcons.speaker_slash),
  AppIconKey.danmaku: PureIconGlyph(CupertinoIcons.text_bubble),
  AppIconKey.folder: PureIconGlyph(CupertinoIcons.folder),
  AppIconKey.folderOpen: PureIconGlyph(CupertinoIcons.folder_fill),
  AppIconKey.cloud: PureIconGlyph(CupertinoIcons.cloud),
  AppIconKey.network: PureIconGlyph(CupertinoIcons.wifi),
  AppIconKey.add: PureIconGlyph(CupertinoIcons.add),
  AppIconKey.delete: PureIconGlyph(CupertinoIcons.trash),
  AppIconKey.edit: PureIconGlyph(CupertinoIcons.pencil),
});

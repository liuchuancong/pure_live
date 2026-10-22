import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconGlyph, PureIconMapping;

/// The Lucide answers (https://lucide.dev), the v4 neutral library.
///
/// Every key is named here — this table is complete, so it is the global
/// backstop in `app_icon_defaults.dart` and nothing reaches the kit's
/// fallback glyph by accident. Names were checked against
/// lucide_icons_flutter 4.0.1's generated icon data.
const PureIconMapping lucideIcons = PureIconMapping({
  // navigation and chrome
  AppIconKey.refresh: PureIconGlyph(LucideIcons.rotateCw),
  AppIconKey.back: PureIconGlyph(LucideIcons.arrowLeft),
  AppIconKey.chevronRight: PureIconGlyph(LucideIcons.chevronRight),
  AppIconKey.more: PureIconGlyph(LucideIcons.ellipsisVertical),
  AppIconKey.apps: PureIconGlyph(LucideIcons.layoutGrid),
  AppIconKey.settings: PureIconGlyph(LucideIcons.settings),
  AppIconKey.search: PureIconGlyph(LucideIcons.search),
  AppIconKey.close: PureIconGlyph(LucideIcons.x),
  AppIconKey.openExternal: PureIconGlyph(LucideIcons.externalLink),
  AppIconKey.link: PureIconGlyph(LucideIcons.link),
  AppIconKey.language: PureIconGlyph(LucideIcons.globe),
  // content states
  AppIconKey.live: PureIconGlyph(LucideIcons.radio),
  AppIconKey.offline: PureIconGlyph(LucideIcons.circleDashed),
  AppIconKey.follow: PureIconGlyph(LucideIcons.heart),
  AppIconKey.followed: PureIconGlyph(LucideIcons.badgeCheck),
  AppIconKey.bookmark: PureIconGlyph(LucideIcons.bookmark),
  AppIconKey.history: PureIconGlyph(LucideIcons.history),
  AppIconKey.timer: PureIconGlyph(LucideIcons.timer),
  AppIconKey.info: PureIconGlyph(LucideIcons.info),
  AppIconKey.error: PureIconGlyph(LucideIcons.circleAlert),
  AppIconKey.blocked: PureIconGlyph(LucideIcons.ban),
  AppIconKey.check: PureIconGlyph(LucideIcons.check),
  AppIconKey.checkCircle: PureIconGlyph(LucideIcons.circleCheck),
  AppIconKey.visibility: PureIconGlyph(LucideIcons.eye),
  AppIconKey.hidden: PureIconGlyph(LucideIcons.eyeOff),
  // room and playback
  AppIconKey.play: PureIconGlyph(LucideIcons.play),
  AppIconKey.pause: PureIconGlyph(LucideIcons.pause),
  AppIconKey.previous: PureIconGlyph(LucideIcons.skipBack),
  AppIconKey.next: PureIconGlyph(LucideIcons.skipForward),
  AppIconKey.subtitles: PureIconGlyph(LucideIcons.captions),
  AppIconKey.video: PureIconGlyph(LucideIcons.video),
  AppIconKey.music: PureIconGlyph(LucideIcons.music),
  AppIconKey.volumeHigh: PureIconGlyph(LucideIcons.volume2),
  AppIconKey.volumeMute: PureIconGlyph(LucideIcons.volumeX),
  AppIconKey.sliders: PureIconGlyph(LucideIcons.slidersHorizontal),
  AppIconKey.quality: PureIconGlyph(LucideIcons.badgeCheck),
  AppIconKey.danmaku: PureIconGlyph(LucideIcons.speech),
  // library and files
  AppIconKey.folder: PureIconGlyph(LucideIcons.folder),
  AppIconKey.folderOpen: PureIconGlyph(LucideIcons.folderOpen),
  AppIconKey.storage: PureIconGlyph(LucideIcons.hardDrive),
  AppIconKey.cloud: PureIconGlyph(LucideIcons.cloud),
  AppIconKey.cloudOff: PureIconGlyph(LucideIcons.cloudOff),
  AppIconKey.cloudDownload: PureIconGlyph(LucideIcons.cloudDownload),
  AppIconKey.download: PureIconGlyph(LucideIcons.download),
  AppIconKey.network: PureIconGlyph(LucideIcons.server),
  AppIconKey.wifiOff: PureIconGlyph(LucideIcons.wifiOff),
  // editing and lists
  AppIconKey.add: PureIconGlyph(LucideIcons.plus),
  AppIconKey.addCircle: PureIconGlyph(LucideIcons.circlePlus),
  AppIconKey.edit: PureIconGlyph(LucideIcons.squarePen),
  AppIconKey.delete: PureIconGlyph(LucideIcons.trash),
  AppIconKey.deleteAll: PureIconGlyph(LucideIcons.trash2),
  AppIconKey.restore: PureIconGlyph(LucideIcons.undo2),
  AppIconKey.comment: PureIconGlyph(LucideIcons.messageSquare),
  AppIconKey.category: PureIconGlyph(LucideIcons.shapes),
  AppIconKey.tag: PureIconGlyph(LucideIcons.tag),
  AppIconKey.palette: PureIconGlyph(LucideIcons.palette),
  AppIconKey.share: PureIconGlyph(LucideIcons.share2),
  AppIconKey.star: PureIconGlyph(LucideIcons.star),
  // shell-only glyphs
  AppIconKey.popular: PureIconGlyph(LucideIcons.flame),
  AppIconKey.iptv: PureIconGlyph(LucideIcons.tv),
  AppIconKey.multiview: PureIconGlyph(LucideIcons.grid2x2),
  AppIconKey.toolbox: PureIconGlyph(LucideIcons.wrench),
  AppIconKey.record: PureIconGlyph(LucideIcons.disc3),
});

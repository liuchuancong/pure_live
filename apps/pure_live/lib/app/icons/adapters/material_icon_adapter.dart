import 'package:flutter/material.dart' show Icons;
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconGlyph, PureIconMapping;

/// The Material answers — Flutter's own icon font, the complete language
/// table for the Material skin. The neutral global backstop is Lucide;
/// Material keys reach it through their own language registration.
const PureIconMapping materialIcons = PureIconMapping({
  // navigation and chrome
  AppIconKey.refresh: PureIconGlyph(Icons.refresh),
  AppIconKey.back: PureIconGlyph(Icons.arrow_back),
  AppIconKey.chevronRight: PureIconGlyph(Icons.chevron_right),
  AppIconKey.more: PureIconGlyph(Icons.more_vert),
  AppIconKey.apps: PureIconGlyph(Icons.apps_outlined),
  AppIconKey.settings: PureIconGlyph(Icons.settings_outlined),
  AppIconKey.search: PureIconGlyph(Icons.search),
  AppIconKey.close: PureIconGlyph(Icons.close),
  AppIconKey.openExternal: PureIconGlyph(Icons.open_in_new),
  AppIconKey.link: PureIconGlyph(Icons.link),
  AppIconKey.language: PureIconGlyph(Icons.language),
  // content states
  AppIconKey.live: PureIconGlyph(Icons.live_tv_outlined),
  AppIconKey.offline: PureIconGlyph(Icons.radio_button_unchecked),
  AppIconKey.follow: PureIconGlyph(Icons.favorite_border),
  AppIconKey.followed: PureIconGlyph(Icons.favorite),
  AppIconKey.bookmark: PureIconGlyph(Icons.bookmark_outlined),
  AppIconKey.history: PureIconGlyph(Icons.history),
  AppIconKey.timer: PureIconGlyph(Icons.timer_outlined),
  AppIconKey.info: PureIconGlyph(Icons.info_outline),
  AppIconKey.error: PureIconGlyph(Icons.error_outline),
  AppIconKey.blocked: PureIconGlyph(Icons.block_outlined),
  AppIconKey.check: PureIconGlyph(Icons.check),
  AppIconKey.checkCircle: PureIconGlyph(Icons.check_circle),
  AppIconKey.visibility: PureIconGlyph(Icons.visibility_outlined),
  AppIconKey.hidden: PureIconGlyph(Icons.visibility_off_outlined),
  // room and playback
  AppIconKey.play: PureIconGlyph(Icons.play_arrow),
  AppIconKey.pause: PureIconGlyph(Icons.pause),
  AppIconKey.previous: PureIconGlyph(Icons.skip_previous),
  AppIconKey.next: PureIconGlyph(Icons.skip_next),
  AppIconKey.subtitles: PureIconGlyph(Icons.subtitles_outlined),
  AppIconKey.video: PureIconGlyph(Icons.videocam_outlined),
  AppIconKey.music: PureIconGlyph(Icons.music_note_outlined),
  AppIconKey.volumeHigh: PureIconGlyph(Icons.volume_up),
  AppIconKey.volumeMute: PureIconGlyph(Icons.volume_off),
  AppIconKey.sliders: PureIconGlyph(Icons.tune),
  AppIconKey.quality: PureIconGlyph(Icons.high_quality),
  AppIconKey.danmaku: PureIconGlyph(Icons.sms),
  // library and files
  AppIconKey.folder: PureIconGlyph(Icons.folder_outlined),
  AppIconKey.folderOpen: PureIconGlyph(Icons.folder_open_outlined),
  AppIconKey.storage: PureIconGlyph(Icons.storage_outlined),
  AppIconKey.cloud: PureIconGlyph(Icons.cloud_outlined),
  AppIconKey.cloudOff: PureIconGlyph(Icons.cloud_off_outlined),
  AppIconKey.cloudDownload: PureIconGlyph(Icons.cloud_download_outlined),
  AppIconKey.download: PureIconGlyph(Icons.download_outlined),
  AppIconKey.network: PureIconGlyph(Icons.dns_outlined),
  AppIconKey.wifiOff: PureIconGlyph(Icons.wifi_off),
  // editing and lists
  AppIconKey.add: PureIconGlyph(Icons.add),
  AppIconKey.addCircle: PureIconGlyph(Icons.add_circle_outline),
  AppIconKey.edit: PureIconGlyph(Icons.edit_outlined),
  AppIconKey.delete: PureIconGlyph(Icons.delete_outline),
  AppIconKey.deleteAll: PureIconGlyph(Icons.delete_sweep_outlined),
  AppIconKey.restore: PureIconGlyph(Icons.restore_outlined),
  AppIconKey.comment: PureIconGlyph(Icons.comment_outlined),
  AppIconKey.category: PureIconGlyph(Icons.category_outlined),
  AppIconKey.tag: PureIconGlyph(Icons.sell_outlined),
  AppIconKey.palette: PureIconGlyph(Icons.palette_outlined),
  AppIconKey.share: PureIconGlyph(Icons.share_outlined),
  AppIconKey.star: PureIconGlyph(Icons.star_border),
  // shell-only glyphs
  AppIconKey.popular: PureIconGlyph(Icons.local_fire_department),
  AppIconKey.iptv: PureIconGlyph(Icons.dns_outlined),
  AppIconKey.multiview: PureIconGlyph(Icons.grid_view_outlined),
  AppIconKey.toolbox: PureIconGlyph(Icons.link_outlined),
  AppIconKey.record: PureIconGlyph(Icons.download_outlined),
});

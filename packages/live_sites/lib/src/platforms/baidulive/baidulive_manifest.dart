import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String baiduliveSiteId = 'baidulive';

/// Baidu Live's stable identity (ARCHITECTURE.md §4.1).
final baiduliveManifest = LiveSiteManifest(
  id: baiduliveSiteId,
  name: {'zh-CN': '百度直播', 'en-US': 'Baidu Live'},
  description: {
    'zh-CN': '百度直播官网的推荐与各频道：一个房间号就是一场直播，结束后有回放就放回放。',
    'en-US': 'Baidu Live: the PC feed of channels, one room per broadcast, ended ones play their recording.',
  },
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['baidu', 'baidulive', '百度直播'],
  icon: LiveAssetRef.of(type: LiveAssetType.bundled, path: 'assets/platforms/baidulive.png'),
);

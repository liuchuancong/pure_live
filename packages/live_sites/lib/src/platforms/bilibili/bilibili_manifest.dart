import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Bilibili Live's stable identity (ARCHITECTURE.md §4.1).
const bilibiliManifest = LiveSiteManifest(
  id: 'bilibili',
  name: {'zh-CN': '哔哩哔哩直播', 'en-US': 'Bilibili Live'},
  description: {
    'zh-CN': '哔哩哔哩直播：分区、推荐、搜索、房间详情、播放地址与经典 JSON 广播弹幕协议。',
    'en-US': 'Bilibili Live: areas, recommendations, search, room detail, play lines and the classic JSON broadcast danmaku protocol.',
  },
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['bili', 'b站', 'bilibili-live'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

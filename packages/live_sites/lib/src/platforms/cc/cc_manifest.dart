import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// NetEase CC's stable identity (ARCHITECTURE.md §4.1).
const ccManifest = LiveSiteManifest(
  id: 'cc',
  name: {'zh-CN': '网易CC直播', 'en-US': 'NetEase CC'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['netease', '163cc', 'wangyi'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

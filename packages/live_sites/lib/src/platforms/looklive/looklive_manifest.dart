import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// LOOK Live's stable identity (ARCHITECTURE.md §4.1).
const lookliveManifest = LiveSiteManifest(
  id: 'looklive',
  name: {'zh-CN': 'LOOK 直播', 'en-US': 'LOOK Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['look', 'wangyi', '163live'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/looklive.png'),
);

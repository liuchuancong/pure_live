import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Steam Broadcast's stable identity (ARCHITECTURE.md §4.1).
const steambroadcastManifest = LiveSiteManifest(
  id: 'steambroadcast',
  name: {'zh-CN': 'Steam 直播', 'en-US': 'Steam Broadcasts'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['steam'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/steambroadcast.png'),
);

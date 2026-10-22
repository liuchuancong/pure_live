import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// YouTube's stable identity (ARCHITECTURE.md §4.1).
const youtubeManifest = LiveSiteManifest(
  id: 'youtube',
  name: {'zh-CN': 'YouTube 直播', 'en-US': 'YouTube Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['yt', 'youtubelive', 'youtube'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/youtube.png'),
);

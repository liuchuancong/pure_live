import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Niconico's stable identity (ARCHITECTURE.md §4.1).
const niconicoManifest = LiveSiteManifest(
  id: 'niconico',
  name: {'zh-CN': ' Nico Nico 直播', 'en-US': 'Niconico'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['nicovideo', 'niconico-live'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

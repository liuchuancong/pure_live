import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Kick's stable identity (ARCHITECTURE.md §4.1).
const kickManifest = LiveSiteManifest(
  id: 'kick',
  name: {'zh-CN': 'Kick直播', 'en-US': 'Kick'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['kickcom'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

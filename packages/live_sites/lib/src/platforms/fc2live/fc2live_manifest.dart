import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// FC2 Live's stable identity (ARCHITECTURE.md §4.1).
const fc2LiveManifest = LiveSiteManifest(
  id: 'fc2live',
  name: {'zh-CN': 'FC2 Live', 'en-US': 'FC2 Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['fc2', 'FC2直播'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// SOOP's stable identity (ARCHITECTURE.md §4.1).
const soopManifest = LiveSiteManifest(
  id: 'soop',
  name: {'zh-CN': 'SOOP直播', 'en-US': 'SOOP'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['afreecatv', 'afreeca', 'sooplive'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/soop.png'),
);

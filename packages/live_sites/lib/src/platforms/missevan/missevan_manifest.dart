import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Missevan's stable identity (ARCHITECTURE.md §4.1).
const missevanManifest = LiveSiteManifest(
  id: 'missevan',
  name: {'zh-CN': '猫耳 FM', 'en-US': 'MissEvan'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['maoer', 'moefm', 'moe'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/missevan.png'),
);

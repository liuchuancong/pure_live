import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Kuaishou's stable identity (ARCHITECTURE.md §4.1).
const kuaishouManifest = LiveSiteManifest(
  id: 'kuaishou',
  name: {'zh-CN': '快手直播', 'en-US': 'Kuaishou'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['kuaishoulive', 'ks', '快手'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

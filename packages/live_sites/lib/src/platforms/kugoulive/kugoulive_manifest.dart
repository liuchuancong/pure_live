import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Kugou Live's stable identity (ARCHITECTURE.md §4.1).
const kugouliveManifest = LiveSiteManifest(
  id: 'kugoulive',
  name: {'zh-CN': '酷狗直播', 'en-US': 'Kugou Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['kugou', 'fanxing'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

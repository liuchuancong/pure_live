import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// AcFun's stable identity (ARCHITECTURE.md §4.1).
const acfunManifest = LiveSiteManifest(
  id: 'acfun',
  name: {'zh-CN': 'AcFun 直播', 'en-US': 'AcFun Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['acfunlive', 'ac', 'acfun直播'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

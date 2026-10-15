import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// YY's (欢聚时代) stable identity (ARCHITECTURE.md §4.1).
const yyManifest = LiveSiteManifest(
  id: 'yy',
  name: {'zh-CN': 'YY 直播', 'en-US': 'YY Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['yy'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

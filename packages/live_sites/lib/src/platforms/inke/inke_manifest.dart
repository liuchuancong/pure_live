import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Inke's stable identity (ARCHITECTURE.md §4.1).
const inkeManifest = LiveSiteManifest(
  id: 'inke',
  name: {'zh-CN': '映客', 'en-US': 'Inke'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['yingke'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

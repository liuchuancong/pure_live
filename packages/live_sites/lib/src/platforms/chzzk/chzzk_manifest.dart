import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// CHZZK's stable identity (ARCHITECTURE.md §4.1).
const chzzkManifest = LiveSiteManifest(
  id: 'chzzk',
  name: {'zh-CN': 'CHZZK', 'en-US': 'CHZZK'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['치지직', 'chzzktv'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/chzzk.png'),
);

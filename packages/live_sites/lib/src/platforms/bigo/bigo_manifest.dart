import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Bigo Live's stable identity (ARCHITECTURE.md §4.1).
const bigoManifest = LiveSiteManifest(
  id: 'bigo',
  name: {'zh-CN': 'Bigo Live', 'en-US': 'Bigo Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['bigolive', 'bigo'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/bigo.png'),
);

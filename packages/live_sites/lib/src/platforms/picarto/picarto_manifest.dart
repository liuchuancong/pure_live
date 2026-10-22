import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String picartoSiteId = 'picarto';

/// Picarto.TV's stable identity (ARCHITECTURE.md §4.1).
const picartoManifest = LiveSiteManifest(
  id: picartoSiteId,
  name: {'zh-CN': 'Picarto', 'en-US': 'Picarto'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['picarto.tv'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/picarto.png'),
);

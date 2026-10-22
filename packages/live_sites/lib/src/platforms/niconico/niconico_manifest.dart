import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String niconicoSiteId = 'niconico';

/// Niconico's stable identity (ARCHITECTURE.md §4.1).
const niconicoManifest = LiveSiteManifest(
  id: niconicoSiteId,
  name: {'zh-CN': ' Nico Nico 直播', 'en-US': 'Niconico'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['nicovideo', 'niconico-live'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/niconico.png'),
);

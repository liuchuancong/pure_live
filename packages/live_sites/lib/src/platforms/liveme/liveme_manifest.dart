import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String livemeSiteId = 'liveme';

/// LiveMe's stable identity (ARCHITECTURE.md §4.1).
final livemeManifest = LiveSiteManifest(
  id: livemeSiteId,
  name: {'zh-CN': 'LiveMe', 'en-US': 'LiveMe'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['liveme'],
  icon: LiveAssetRef.of(type: LiveAssetType.bundled, path: 'assets/platforms/liveme.png'),
);

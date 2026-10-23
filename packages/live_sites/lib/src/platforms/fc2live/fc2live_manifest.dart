import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String fc2LiveSiteId = 'fc2live';

/// FC2 Live's stable identity (ARCHITECTURE.md §4.1).
final fc2LiveManifest = LiveSiteManifest(
  id: fc2LiveSiteId,
  name: {'zh-CN': 'FC2 Live', 'en-US': 'FC2 Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['fc2', 'FC2直播'],
  icon: LiveAssetRef.of(type: LiveAssetType.bundled, path: 'assets/platforms/fc2live.png'),
);

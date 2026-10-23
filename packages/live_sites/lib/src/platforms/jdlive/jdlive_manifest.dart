import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String jdliveSiteId = 'jdlive';

/// JD Live's stable identity (ARCHITECTURE.md §4.1).
final jdliveManifest = LiveSiteManifest(
  id: jdliveSiteId,
  name: {'zh-CN': '京东直播', 'en-US': 'JD Live'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['jd', 'jdlive', 'jingdong'],
  icon: LiveAssetRef.of(type: LiveAssetType.bundled, path: 'assets/platforms/jdlive.png'),
);

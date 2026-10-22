import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String douyuSiteId = 'douyu';

/// Douyu's stable identity (ARCHITECTURE.md §4.1).
const douyuManifest = LiveSiteManifest(
  id: douyuSiteId,
  name: {'zh-CN': '斗鱼直播', 'en-US': 'Douyu'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['douyutv'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/douyu.png'),
);

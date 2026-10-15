import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Six Rooms' stable identity (ARCHITECTURE.md §4.1).
const sixroomManifest = LiveSiteManifest(
  id: 'sixroom',
  name: {'zh-CN': '六间房直播', 'en-US': 'Six Rooms'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['6.cn', '6rooms', 'sixrooms'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

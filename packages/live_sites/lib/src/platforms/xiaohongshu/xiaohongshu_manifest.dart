import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Xiaohongshu's stable identity (ARCHITECTURE.md §4.1).
const xiaohongshuManifest = LiveSiteManifest(
  id: 'xiaohongshu',
  name: {'zh-CN': '小红书', 'en-US': 'Xiaohongshu'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['xhs', 'rednote'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

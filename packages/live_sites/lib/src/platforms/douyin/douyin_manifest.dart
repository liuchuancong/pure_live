import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Douyin's stable identity (ARCHITECTURE.md §4.1).
const douyinManifest = LiveSiteManifest(
  id: 'douyin',
  name: {'zh-CN': '抖音直播', 'en-US': 'Douyin'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['douyinlive', 'tiktok-live'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

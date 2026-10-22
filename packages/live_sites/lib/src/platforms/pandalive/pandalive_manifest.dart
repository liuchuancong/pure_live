import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// PandaTV's stable identity (ARCHITECTURE.md §4.1).
const pandaliveManifest = LiveSiteManifest(
  id: 'pandalive',
  name: {'zh-CN': 'PandaTV', 'en-US': 'PandaTV'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['pandatv', 'pandalive.co.kr'],
  icon: LiveAssetRef(type: LiveAssetType.bundled, path: 'assets/platforms/pandalive.png'),
);

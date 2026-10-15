import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// KilaKila's stable identity (ARCHITECTURE.md §4.1).
const kilakilaManifest = LiveSiteManifest(
  id: 'kilakila',
  name: {'zh-CN': '克拉克拉', 'en-US': 'KilaKila'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['kila', 'hongdou', 'hongdoufm'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

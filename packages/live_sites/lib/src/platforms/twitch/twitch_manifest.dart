import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// Twitch's stable identity (ARCHITECTURE.md §4.1).
const twitchManifest = LiveSiteManifest(
  id: 'twitch',
  name: {'zh-CN': 'Twitch 直播', 'en-US': 'Twitch'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['tw', 'twitchtv'],
  icon: LiveAssetRef(type: LiveAssetType.platformDefault),
);

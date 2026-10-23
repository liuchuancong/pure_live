import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/site_facts.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String twitcastingSiteId = SiteIds.twitcasting;

/// TwitCasting's stable identity (ARCHITECTURE.md §4.1).
final twitcastingManifest = LiveSiteManifest(
  id: twitcastingSiteId,
  name: {'zh-CN': 'TwitCasting', 'en-US': 'TwitCasting'},
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['twitcasting.tv', 'twitcasting_tv', 'tc'],
  icon: LiveAssetRef.of(type: LiveAssetType.bundled, path: 'assets/platforms/twitcasting.png'),
);

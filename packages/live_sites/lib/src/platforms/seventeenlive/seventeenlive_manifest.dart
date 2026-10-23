import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/site_facts.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';

/// The one stable id of this platform; its manifest, errors and
/// models all read it from here.
const String seventeenliveSiteId = SiteIds.seventeenLive;

/// 17LIVE's stable identity (ARCHITECTURE.md §4.1).
///
/// The description is the platform's directory notice: what its recommendations,
/// areas and search cover — the reference carried it as a `directoryNoticeKey`,
/// and this contract has no directory notice of its own, so the scope belongs to
/// the slow-changing metadata instead.
final seventeenliveManifest = LiveSiteManifest(
  id: seventeenliveSiteId,
  name: {'zh-CN': '17LIVE', 'en-US': '17LIVE'},
  description: {
    'zh-CN': SeventeenLiveEndpoints.directoryScope,
    'en-US':
        'Recommendations and areas are the 17LIVE home-page lives of the Japan, Taiwan and Hong Kong regions, '
        'not every live. Search finds broadcasters who are live now; a room id or a pasted 17LIVE room or '
        'profile link works too.',
  },
  version: '0.1.0',
  contractVersion: '1.0.0',
  aliases: ['17直播', '17media', 'イチナナ'],
  icon: LiveAssetRef.of(type: LiveAssetType.bundled, path: 'assets/platforms/17live.png'),
);

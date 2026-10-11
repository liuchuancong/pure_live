/// Site domain and adaptation contracts for Pure Live.
///
/// A site adapter implements `LiveSite` and is registered by id in the
/// `SiteRegistry`. Room-level operations — detail, play qualities, play
/// URLs, status refresh — take the `LiveRoom` itself: the room already
/// carries the platform id, the room id and the adapter's runtime
/// context. Directory browsing and search keep dedicated query inputs;
/// nothing forces a hollow room into an API that has no use for one.
///
/// Danmaku is a capability: `site is LiveDanmakuCapability` decides
/// whether a room can open a `LiveDanmakuSession`. Public stream models
/// (`LiveMessage`, `LiveGift`, `LiveAudienceUpdate`) are what decoders
/// map platform packets into; UI never sees platform wire formats.
library;

export 'src/common/headers/site_headers.dart';
export 'src/common/normalization/site_counts.dart';
export 'src/common/normalization/site_images.dart';
export 'src/common/normalization/site_text.dart';
export 'src/common/parsing/site_json.dart';
export 'src/common/urls/site_urls.dart';
export 'src/contracts/directory_query.dart';
export 'src/contracts/live_site.dart';
export 'src/contracts/site_capability.dart';
export 'src/contracts/site_error.dart';
export 'src/models/live_area.dart';
export 'src/models/live_gift.dart';
export 'src/models/live_message.dart';
export 'src/models/live_play_line.dart';
export 'src/models/live_room.dart';
export 'src/models/live_status.dart';
export 'src/platforms/iptv.dart';
export 'src/registry/site_factories.dart';
export 'src/registry/site_ids.dart';
export 'src/registry/site_metadata.dart';
export 'src/registry/site_registry.dart';

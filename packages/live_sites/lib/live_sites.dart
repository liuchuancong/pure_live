/// Live-site integration contract for Pure Live.
///
/// A platform is a `LiveSite` exposing stable identity (`LiveSiteManifest`) and
/// a lifecycle (`initialize` / `dispose`); every feature is an optional
/// capability retrieved through `capability<T>()`. Expected failures at
/// capability boundaries are values, not thrown exceptions: each returns an
/// `Either<LiveSiteError, T>`, so a caller can distinguish "no such room" from
/// "not supported" from "rate limited" without try/catch.
///
/// The shared models are plain immutable Freezed value types; identity-bearing
/// entities (rooms, anchors) compare by (siteId, id) so refreshes stay stable.
/// Platform adapters, their parsers and signing live under `src/platforms/` and
/// are not part of this public surface.
library;

export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_category_provider.dart';
export 'src/capabilities/live_danmaku_provider.dart';
export 'src/capabilities/live_discovery_provider.dart';
export 'src/capabilities/live_hot_provider.dart';
export 'src/capabilities/live_link_resolver.dart';
export 'src/capabilities/live_playback_provider.dart';
export 'src/capabilities/live_room_provider.dart';
export 'src/capabilities/live_search_provider.dart';
export 'src/capabilities/live_site_capability.dart';
export 'src/capabilities/live_web_search_provider.dart';
export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_error.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_registry.dart';
export 'src/core/live_site_runtime_info.dart';
export 'src/internal/built_in_sites.dart';
export 'src/models/live_anchor/live_anchor.dart';
export 'src/models/live_asset_ref/live_asset_ref.dart';
export 'src/models/live_category/live_category.dart';
export 'src/models/live_danmaku_event/live_danmaku_event.dart';
export 'src/models/live_page/live_page.dart';
export 'src/models/live_room/live_room.dart';
export 'src/models/live_search_result/live_search_result.dart';
export 'src/models/live_stream/live_stream.dart';

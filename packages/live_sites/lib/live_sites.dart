/// Live-site integration contract for Pure Live.
///
/// A platform is a `LiveSite` exposing stable identity (`LiveSiteManifest`) and
/// a lifecycle (`initialize` / `dispose`); every feature is an optional
/// capability retrieved through `capability<T>()`. Expected failures at
/// capability boundaries are values, not thrown exceptions: each returns an
/// `Either<LiveSiteError, T>`, so a caller can distinguish "no such room" from
/// "not supported" from "rate limited" without try/catch.
///
/// The shared models are immutable value types built faithfully to `live_core`:
/// pure data uses Freezed, while identity-bearing or normalizing entities
/// (rooms, areas, play lines) are hand-written and compare by a stable identity
/// (a room by `(platform, roomId)`) so refreshes stay stable. A room's area is a
/// `LiveArea`; playback is reported as `LivePlayQuality` and `LivePlayLine`.
/// Platform adapters, their parsers and signing live under `src/platforms/` and
/// are not part of this public surface.
library;

export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_area_provider.dart';
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
export 'src/core/site_error/site_error.dart';
export 'src/internal/built_in_sites.dart';
export 'src/models/live_anchor/live_anchor.dart';
export 'src/models/live_area/live_area.dart';
export 'src/models/live_asset_ref/live_asset_ref.dart';
export 'src/models/live_audience/live_audience.dart';
export 'src/models/live_catch_up/live_catch_up.dart';
export 'src/models/live_follow_group/live_follow_group.dart';
export 'src/models/live_gift/live_gift.dart';
export 'src/models/live_gift_combo/live_gift_combo.dart';
export 'src/models/live_guide/live_guide.dart';
export 'src/models/live_input_recipe/live_input_recipe.dart';
export 'src/models/live_message/live_message.dart';
export 'src/models/live_page/live_page.dart';
export 'src/models/live_play_line/live_play_line.dart';
export 'src/models/live_play_quality/live_play_quality.dart';
export 'src/models/live_restriction/live_restriction.dart';
export 'src/models/live_room/live_room.dart';
export 'src/models/live_room_link/live_room_link.dart';
export 'src/models/live_search_result/live_search_result.dart';
export 'src/models/live_status/live_status.dart';

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

// Optional capabilities a site may implement.
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

// Shared logic that operates on the models but is not itself a model type.
export 'src/common/audience/audience_numbers.dart';
export 'src/common/gift/gift_combo.dart';
export 'src/common/gift/gift_value.dart';
export 'src/common/message/super_chat_price.dart';

export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_error.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_registry.dart';
export 'src/core/live_site_runtime_info.dart';
export 'src/core/site_error/site_error.dart';
export 'src/internal/built_in_sites.dart';

// Shared models, one type per file.
export 'src/models/live_anchor/live_anchor.dart';
export 'src/models/live_area/live_area.dart';
export 'src/models/live_asset_ref/live_asset_ref.dart';
export 'src/models/live_asset_type/live_asset_type.dart';
export 'src/models/live_audience/live_audience.dart';
export 'src/models/live_audience_metric_kind/live_audience_metric_kind.dart';
export 'src/models/live_audience_metric_type/live_audience_metric_type.dart';
export 'src/models/live_audience_platform_capability/live_audience_platform_capability.dart';
export 'src/models/live_audience_rank_key/live_audience_rank_key.dart';
export 'src/models/live_audience_update/live_audience_update.dart';
export 'src/models/live_badge/live_badge.dart';
export 'src/models/live_broadcast/live_broadcast.dart';
export 'src/models/live_catch_up/live_catch_up.dart';
export 'src/models/live_emote/live_emote.dart';
export 'src/models/live_follow_group/live_follow_group.dart';
export 'src/models/live_gift/live_gift.dart';
export 'src/models/live_gift_kind/live_gift_kind.dart';
export 'src/models/live_gift_tier/live_gift_tier.dart';
export 'src/models/live_gift_unit/live_gift_unit.dart';
export 'src/models/live_guide/live_guide.dart';
export 'src/models/live_input_recipe/live_input_recipe.dart';
export 'src/models/live_link_resolution/live_link_resolution.dart';
export 'src/models/live_message/live_message.dart';
export 'src/models/live_message_color/live_message_color.dart';
export 'src/models/live_message_placement/live_message_placement.dart';
export 'src/models/live_message_style/live_message_style.dart';
export 'src/models/live_message_type/live_message_type.dart';
export 'src/models/live_notice_kind/live_notice_kind.dart';
export 'src/models/live_page/live_page.dart';
export 'src/models/live_page_request/live_page_request.dart';
export 'src/models/live_play_lease/live_play_lease.dart';
export 'src/models/live_play_line/live_play_line.dart';
export 'src/models/live_play_quality/live_play_quality.dart';
export 'src/models/live_restriction/live_restriction.dart';
export 'src/models/live_retraction/live_retraction.dart';
export 'src/models/live_room/live_room.dart';
export 'src/models/live_room_content/live_room_content.dart';
export 'src/models/live_room_link/live_room_link.dart';
export 'src/models/live_room_links/live_room_links.dart';
export 'src/models/live_room_local/live_room_local.dart';
export 'src/models/live_room_runtime/live_room_runtime.dart';
export 'src/models/live_search_request/live_search_request.dart';
export 'src/models/live_search_result/live_search_result.dart';
export 'src/models/live_search_target/live_search_target.dart';
export 'src/models/live_status/live_status.dart';
export 'src/models/live_status_index_converter/live_status_index_converter.dart';
export 'src/models/live_stream_format/live_stream_format.dart';
export 'src/models/live_super_chat_message/live_super_chat_message.dart';

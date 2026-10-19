/// Live Sites — unified integration contract for live platforms.
///
/// One package, one public surface: core contracts, optional capabilities,
/// model domains (one barrel per domain) plus enums/converters barrels.
/// Platform implementations under src/platforms/ are private.
library;

// capabilities
export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_area_provider.dart';
export 'src/capabilities/live_auth_capability.dart';
export 'src/capabilities/live_danmaku_provider.dart';
export 'src/capabilities/live_discovery_provider.dart';
export 'src/capabilities/live_hot_provider.dart';
export 'src/capabilities/live_link_resolver.dart';
export 'src/capabilities/live_playback_provider.dart';
export 'src/capabilities/live_room_provider.dart';
export 'src/capabilities/live_search_provider.dart';
export 'src/capabilities/live_site_capability.dart';
export 'src/capabilities/live_suggest_capability.dart';
export 'src/capabilities/live_web_search_provider.dart';

// core
export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_error.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_registry.dart';
export 'src/core/live_site_runtime_info.dart';

// internal entry point
export 'src/internal/built_in_sites.dart';

// models — domain barrels
export 'src/models/anchor/anchor.dart';
export 'src/models/area/area.dart';
export 'src/models/asset/asset.dart';
export 'src/models/audience/audience.dart';
export 'src/models/converters/converters.dart';
export 'src/models/enums/enums.dart';
export 'src/models/gift/gift.dart';
export 'src/models/guide/guide.dart';
export 'src/models/message/message.dart';
export 'src/models/page/page.dart';
export 'src/models/play/play.dart';
export 'src/models/room/room.dart';
export 'src/models/search/search.dart';
export 'src/models/super_chat/super_chat.dart';
// Douyu renewal seam (consumed by the application's account store): the
// login store the adapter reads beside the cookie, the adapter's public
// renewal surface, and the cookie parser the status cards answer from.
export 'src/platforms/douyu/douyu_login_store.dart';
export 'src/platforms/douyu/douyu_site.dart';
export 'src/platforms/douyu/parsers/douyu_account.dart';
// iptv seam (consumed by live_iptv; see ARCHITECTURE.md §11)
export 'src/platforms/iptv/iptv_channel_source.dart';

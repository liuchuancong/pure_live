/// The tiktok adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/tiktok_endpoints.dart';
export 'api/tiktok_http.dart';
export 'capabilities/tiktok_discovery_provider.dart';
export 'capabilities/tiktok_link_resolver.dart';
export 'capabilities/tiktok_play_lease_lookup.dart';
export 'capabilities/tiktok_playback_provider.dart';
export 'capabilities/tiktok_room_provider.dart';
export 'capabilities/tiktok_room_refresh.dart';
export 'capabilities/tiktok_search_provider.dart';
export 'capabilities/tiktok_status_check.dart';
export 'parsers/tiktok_failure.dart';
export 'parsers/tiktok_json.dart';
export 'parsers/tiktok_link.dart';
export 'parsers/tiktok_room_parser.dart';
export 'tiktok_manifest.dart';
export 'tiktok_site.dart';

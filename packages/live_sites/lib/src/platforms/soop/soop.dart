/// The soop adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/soop_endpoints.dart';
export 'api/soop_http.dart';
export 'capabilities/soop_area_provider.dart';
export 'capabilities/soop_discovery_provider.dart';
export 'capabilities/soop_link_resolver.dart';
export 'capabilities/soop_playback_provider.dart';
export 'capabilities/soop_room_provider.dart';
export 'capabilities/soop_search_provider.dart';
export 'danmaku/soop_danmaku_codec.dart';
export 'danmaku/soop_danmaku_session.dart';
export 'parsers/soop_failure.dart';
export 'parsers/soop_json.dart';
export 'parsers/soop_link.dart';
export 'parsers/soop_room_parser.dart';
export 'soop_manifest.dart';
export 'soop_site.dart';

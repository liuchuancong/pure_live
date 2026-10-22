/// The baidulive adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/baidulive_endpoints.dart';
export 'api/baidulive_http.dart';
export 'api/baidulive_models.dart';
export 'baidulive_manifest.dart';
export 'baidulive_site.dart';
export 'capabilities/baidulive_area_provider.dart';
export 'capabilities/baidulive_discovery_provider.dart';
export 'capabilities/baidulive_link_resolver.dart';
export 'capabilities/baidulive_playback_provider.dart';
export 'capabilities/baidulive_room_provider.dart';
export 'capabilities/baidulive_search_provider.dart';
export 'danmaku/baidulive_danmaku_codec.dart';
export 'danmaku/baidulive_danmaku_session.dart';
export 'parsers/baidulive_failure.dart';
export 'parsers/baidulive_json.dart';
export 'parsers/baidulive_play_parser.dart';
export 'parsers/baidulive_room_parser.dart';

/// The jdlive adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/jdlive_endpoints.dart';
export 'api/jdlive_http.dart';
export 'capabilities/jdlive_area_provider.dart';
export 'capabilities/jdlive_discovery_provider.dart';
export 'capabilities/jdlive_link_resolver.dart';
export 'capabilities/jdlive_playback_provider.dart';
export 'capabilities/jdlive_room_provider.dart';
export 'capabilities/jdlive_room_refresh.dart';
export 'capabilities/jdlive_search_provider.dart';
export 'capabilities/jdlive_status_check.dart';
export 'danmaku/jdlive_danmaku_codec.dart';
export 'danmaku/jdlive_danmaku_session.dart';
export 'jdlive_manifest.dart';
export 'jdlive_site.dart';
export 'parsers/jdlive_failure.dart';
export 'parsers/jdlive_json.dart';
export 'parsers/jdlive_room_parser.dart';

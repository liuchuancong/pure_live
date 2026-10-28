/// The picarto adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/picarto_endpoints.dart';
export 'api/picarto_http.dart';
export 'capabilities/picarto_area_provider.dart';
export 'capabilities/picarto_discovery_provider.dart';
export 'capabilities/picarto_link_resolver.dart';
export 'capabilities/picarto_play_recovery.dart';
export 'capabilities/picarto_playback_provider.dart';
export 'capabilities/picarto_room_provider.dart';
export 'capabilities/picarto_room_refresh.dart';
export 'capabilities/picarto_search_provider.dart';
export 'capabilities/picarto_status_check.dart';
export 'danmaku/picarto_danmaku_codec.dart';
export 'danmaku/picarto_danmaku_session.dart';
export 'parsers/picarto_failure.dart';
export 'parsers/picarto_json.dart';
export 'parsers/picarto_link.dart';
export 'parsers/picarto_room_parser.dart';
export 'picarto_manifest.dart';
export 'picarto_site.dart';

/// The kuaishou adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/kuaishou_endpoints.dart';
export 'api/kuaishou_http.dart';
export 'capabilities/kuaishou_area_provider.dart';
export 'capabilities/kuaishou_auth_provider.dart';
export 'capabilities/kuaishou_discovery_provider.dart';
export 'capabilities/kuaishou_link_resolver.dart';
export 'capabilities/kuaishou_play_lease_lookup.dart';
export 'capabilities/kuaishou_play_recovery.dart';
export 'capabilities/kuaishou_playback_provider.dart';
export 'capabilities/kuaishou_room_provider.dart';
export 'capabilities/kuaishou_room_refresh.dart';
export 'capabilities/kuaishou_search_provider.dart';
export 'capabilities/kuaishou_status_check.dart';
export 'danmaku/kuaishou_danmaku_codec.dart';
export 'danmaku/kuaishou_danmaku_session.dart';
export 'kuaishou_manifest.dart';
export 'kuaishou_site.dart';
export 'parsers/kuaishou_failure.dart';
export 'parsers/kuaishou_json.dart'
    hide decodeJson, fields, imageUrl, jsonInt, jsonList, jsonObject, jsonSnippet, jsonString, jsonText, text, truthy;
export 'parsers/kuaishou_play_parser.dart';
export 'parsers/kuaishou_room_parser.dart';

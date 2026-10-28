/// The niconico adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/niconico_endpoints.dart';
export 'api/niconico_http.dart';
export 'capabilities/niconico_area_provider.dart';
export 'capabilities/niconico_discovery_provider.dart';
export 'capabilities/niconico_link_resolver.dart';
export 'capabilities/niconico_playback_provider.dart';
export 'capabilities/niconico_room_provider.dart';
export 'capabilities/niconico_room_refresh.dart';
export 'capabilities/niconico_search_provider.dart';
export 'capabilities/niconico_status_check.dart';
export 'danmaku/niconico_danmaku_codec.dart';
export 'danmaku/niconico_danmaku_session.dart';
export 'danmaku/niconico_protobuf.dart' hide niconicoSplitDelimited;
export 'danmaku/niconico_seat_session.dart';
export 'niconico_manifest.dart';
export 'niconico_site.dart';
export 'parsers/niconico_failure.dart';
export 'parsers/niconico_json.dart'
    hide decodeHtmlEntities, decodeJson, jsonInt, jsonList, jsonObject, jsonSnippet, jsonString, jsonUrl;
export 'parsers/niconico_play_parser.dart';
export 'parsers/niconico_room_parser.dart';

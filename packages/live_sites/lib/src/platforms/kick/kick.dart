/// The kick adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/kick_endpoints.dart';
export 'api/kick_http.dart';
export 'capabilities/kick_area_provider.dart';
export 'capabilities/kick_discovery_provider.dart';
export 'capabilities/kick_link_resolver.dart';
export 'capabilities/kick_play_recovery.dart';
export 'capabilities/kick_playback_provider.dart';
export 'capabilities/kick_room_provider.dart';
export 'capabilities/kick_room_refresh.dart';
export 'capabilities/kick_search_provider.dart';
export 'capabilities/kick_status_check.dart';
export 'danmaku/kick_danmaku_codec.dart';
export 'danmaku/kick_danmaku_session.dart';
export 'kick_manifest.dart';
export 'kick_site.dart';
export 'parsers/kick_failure.dart';
export 'parsers/kick_json.dart'
    hide
        decodeJson,
        jsonCount,
        jsonDouble,
        jsonInt,
        jsonList,
        jsonMessageTime,
        jsonObject,
        jsonOrText,
        jsonSnippet,
        jsonString,
        jsonTime;
export 'parsers/kick_play_parser.dart';
export 'parsers/kick_room_parser.dart';

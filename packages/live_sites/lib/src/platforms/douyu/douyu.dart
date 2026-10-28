/// The douyu adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/douyu_endpoints.dart';
export 'api/douyu_http.dart';
export 'capabilities/douyu_area_provider.dart';
export 'capabilities/douyu_auth_provider.dart';
export 'capabilities/douyu_discovery_provider.dart';
export 'capabilities/douyu_link_resolver.dart';
export 'capabilities/douyu_play_recovery.dart';
export 'capabilities/douyu_playback_provider.dart';
export 'capabilities/douyu_room_provider.dart';
export 'capabilities/douyu_room_refresh.dart';
export 'capabilities/douyu_search_provider.dart';
export 'capabilities/douyu_status_check.dart';
export 'danmaku/douyu_danmaku_session.dart';
export 'danmaku/douyu_stt_codec.dart';
export 'douyu_login_store.dart';
export 'douyu_manifest.dart';
export 'douyu_site.dart';
export 'parsers/douyu_account.dart';
export 'parsers/douyu_failure.dart';
export 'parsers/douyu_gift_parser.dart';
export 'parsers/douyu_json.dart'
    hide
        decodeHtmlEntities,
        decodeJson,
        htmlPageText,
        jsonCount,
        jsonInt,
        jsonList,
        jsonObject,
        jsonSnippet,
        jsonString,
        jsonUrl;
export 'parsers/douyu_play_parser.dart';
export 'parsers/douyu_room_parser.dart' hide roomGiftsOf;

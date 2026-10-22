/// The bigo adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/bigo_endpoints.dart';
export 'api/bigo_http.dart';
export 'api/bigo_token.dart';
export 'bigo_manifest.dart';
export 'bigo_site.dart';
export 'capabilities/bigo_area_provider.dart';
export 'capabilities/bigo_discovery_provider.dart';
export 'capabilities/bigo_link_resolver.dart';
export 'capabilities/bigo_playback_provider.dart';
export 'capabilities/bigo_room_provider.dart';
export 'capabilities/bigo_search_provider.dart';
export 'danmaku/bigo_chat_visitor.dart';
export 'danmaku/bigo_danmaku_codec.dart';
export 'danmaku/bigo_danmaku_session.dart';
export 'parsers/bigo_failure.dart';
export 'parsers/bigo_hls_protection.dart';
export 'parsers/bigo_json.dart'
    hide
        binary,
        boolean,
        checkStatus,
        count,
        jsonpObject,
        list,
        object,
        optionalText,
        owner,
        picture,
        playlist,
        snippet,
        successData,
        text;
export 'parsers/bigo_room_parser.dart';
export 'parsers/bigo_studio.dart';

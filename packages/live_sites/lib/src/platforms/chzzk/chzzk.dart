/// The chzzk adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/chzzk_endpoints.dart';
export 'api/chzzk_http.dart';
export 'capabilities/chzzk_area_provider.dart';
export 'capabilities/chzzk_discovery_provider.dart';
export 'capabilities/chzzk_link_resolver.dart';
export 'capabilities/chzzk_playback_provider.dart';
export 'capabilities/chzzk_room_provider.dart';
export 'capabilities/chzzk_room_refresh.dart';
export 'capabilities/chzzk_search_provider.dart';
export 'capabilities/chzzk_status_check.dart';
export 'chzzk_manifest.dart';
export 'chzzk_site.dart';
export 'danmaku/chzzk_danmaku_codec.dart';
export 'danmaku/chzzk_danmaku_session.dart';
export 'parsers/chzzk_failure.dart';
export 'parsers/chzzk_json.dart'
    hide
        areaName,
        categoryTypeName,
        channelId,
        content,
        cover,
        image,
        isAreaId,
        isChannelId,
        jsonCount,
        jsonInt,
        list,
        object,
        online,
        optionalList,
        optionalObject,
        paid,
        regionLocked,
        seoulTime,
        snippet,
        statusFailure,
        stringify,
        text;
export 'parsers/chzzk_play_parser.dart';
export 'parsers/chzzk_room_parser.dart';

/// The acfun adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'acfun_manifest.dart';
export 'acfun_site.dart';
export 'api/acfun_endpoints.dart';
export 'api/acfun_http.dart';
export 'capabilities/acfun_area_provider.dart';
export 'capabilities/acfun_discovery_provider.dart';
export 'capabilities/acfun_link_resolver.dart';
export 'capabilities/acfun_playback_provider.dart';
export 'capabilities/acfun_room_provider.dart';
export 'capabilities/acfun_search_provider.dart';
export 'danmaku/acfun_danmaku_codec.dart';
export 'danmaku/acfun_danmaku_session.dart';
export 'danmaku/acfun_protobuf.dart';
export 'parsers/acfun_failure.dart';
export 'parsers/acfun_html.dart' hide acfunHtmlEntities;
export 'parsers/acfun_json.dart';
export 'parsers/acfun_play_parser.dart';
export 'parsers/acfun_room_parser.dart';

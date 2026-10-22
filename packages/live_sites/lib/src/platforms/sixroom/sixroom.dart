/// The sixroom adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/sixroom_endpoints.dart';
export 'api/sixroom_http.dart';
export 'capabilities/sixroom_area_provider.dart';
export 'capabilities/sixroom_discovery_provider.dart';
export 'capabilities/sixroom_link_resolver.dart';
export 'capabilities/sixroom_playback_provider.dart';
export 'capabilities/sixroom_room_provider.dart';
export 'capabilities/sixroom_search_provider.dart';
export 'danmaku/sixroom_danmaku_codec.dart';
export 'danmaku/sixroom_danmaku_session.dart';
export 'parsers/sixroom_failure.dart';
export 'parsers/sixroom_html.dart';
export 'parsers/sixroom_json.dart';
export 'parsers/sixroom_room_parser.dart';
export 'sixroom_manifest.dart';
export 'sixroom_site.dart';

/// The kilakila adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/kilakila_endpoints.dart';
export 'api/kilakila_http.dart';
export 'capabilities/kilakila_area_provider.dart';
export 'capabilities/kilakila_discovery_provider.dart';
export 'capabilities/kilakila_link_resolver.dart';
export 'capabilities/kilakila_playback_provider.dart';
export 'capabilities/kilakila_room_provider.dart';
export 'capabilities/kilakila_search_provider.dart';
export 'danmaku/kilakila_danmaku_codec.dart';
export 'danmaku/kilakila_danmaku_session.dart';
export 'kilakila_manifest.dart';
export 'kilakila_site.dart';
export 'parsers/kilakila_failure.dart';
export 'parsers/kilakila_html.dart';
export 'parsers/kilakila_json.dart';
export 'parsers/kilakila_link.dart';
export 'parsers/kilakila_room_parser.dart';

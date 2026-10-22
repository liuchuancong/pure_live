/// The inke adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/inke_endpoints.dart';
export 'api/inke_http.dart';
export 'capabilities/inke_area_provider.dart';
export 'capabilities/inke_discovery_provider.dart';
export 'capabilities/inke_link_resolver.dart';
export 'capabilities/inke_playback_provider.dart';
export 'capabilities/inke_room_provider.dart';
export 'capabilities/inke_search_provider.dart';
export 'inke_manifest.dart';
export 'inke_site.dart';
export 'parsers/inke_failure.dart';
export 'parsers/inke_json.dart';
export 'parsers/inke_room_parser.dart';

/// The cc adapter as one public unit: manifest, site class, capabilities,
/// transport and parsers. Adapter-internal top-level helpers stay hidden.
library;

export 'api/cc_endpoints.dart';
export 'api/cc_http.dart';
export 'capabilities/cc_area_provider.dart';
export 'capabilities/cc_discovery_provider.dart';
export 'capabilities/cc_link_resolver.dart';
export 'capabilities/cc_playback_provider.dart';
export 'capabilities/cc_room_provider.dart';
export 'capabilities/cc_room_refresh.dart';
export 'capabilities/cc_search_provider.dart';
export 'capabilities/cc_status_check.dart';
export 'cc_manifest.dart';
export 'cc_site.dart';
export 'parsers/cc_catalog_parser.dart';
export 'parsers/cc_failure.dart';
export 'parsers/cc_json.dart';
export 'parsers/cc_play_parser.dart';
export 'parsers/cc_room_parser.dart';

/// The weibo adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/weibo_endpoints.dart';
export 'api/weibo_http.dart';
export 'capabilities/weibo_area_provider.dart';
export 'capabilities/weibo_discovery_provider.dart';
export 'capabilities/weibo_link_resolver.dart';
export 'capabilities/weibo_playback_provider.dart';
export 'capabilities/weibo_room_provider.dart';
export 'capabilities/weibo_room_refresh.dart';
export 'capabilities/weibo_search_provider.dart';
export 'capabilities/weibo_status_check.dart';
export 'parsers/weibo_failure.dart';
export 'parsers/weibo_json.dart';
export 'parsers/weibo_room_parser.dart';
export 'weibo_manifest.dart';
export 'weibo_site.dart';

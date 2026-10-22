/// The showroom adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/showroom_endpoints.dart';
export 'api/showroom_http.dart';
export 'capabilities/showroom_area_provider.dart';
export 'capabilities/showroom_discovery_provider.dart';
export 'capabilities/showroom_link_resolver.dart';
export 'capabilities/showroom_playback_provider.dart';
export 'capabilities/showroom_room_provider.dart';
export 'capabilities/showroom_search_provider.dart';
export 'danmaku/showroom_danmaku_codec.dart';
export 'danmaku/showroom_danmaku_session.dart';
export 'parsers/showroom_failure.dart';
export 'parsers/showroom_json.dart';
export 'parsers/showroom_models.dart';
export 'parsers/showroom_parser.dart';
export 'showroom_manifest.dart';
export 'showroom_site.dart';

/// The fc2live adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/fc2live_endpoints.dart';
export 'api/fc2live_http.dart';
export 'capabilities/fc2live_area_provider.dart';
export 'capabilities/fc2live_discovery_provider.dart';
export 'capabilities/fc2live_link_resolver.dart';
export 'capabilities/fc2live_playback_provider.dart';
export 'capabilities/fc2live_room_provider.dart';
export 'capabilities/fc2live_search_provider.dart';
export 'danmaku/fc2live_control.dart';
export 'danmaku/fc2live_danmaku_codec.dart';
export 'danmaku/fc2live_danmaku_session.dart';
export 'fc2live_manifest.dart';
export 'fc2live_site.dart';
export 'parsers/fc2live_failure.dart';
export 'parsers/fc2live_json.dart';
export 'parsers/fc2live_play_parser.dart';
export 'parsers/fc2live_room_parser.dart';

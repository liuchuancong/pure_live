/// The kugoulive adapter as one public unit: manifest, site class, capabilities,
/// transport, parsers and (where the platform has it) danmaku. Adapter-internal
/// top-level helpers stay hidden.
library;

export 'api/kugoulive_endpoints.dart';
export 'api/kugoulive_http.dart';
export 'capabilities/kugoulive_area_provider.dart';
export 'capabilities/kugoulive_discovery_provider.dart';
export 'capabilities/kugoulive_link_resolver.dart';
export 'capabilities/kugoulive_playback_provider.dart';
export 'capabilities/kugoulive_room_provider.dart';
export 'capabilities/kugoulive_search_provider.dart';
export 'danmaku/kugoulive_danmaku_codec.dart';
export 'danmaku/kugoulive_danmaku_session.dart';
export 'danmaku/kugoulive_protobuf.dart';
export 'kugoulive_manifest.dart';
export 'kugoulive_site.dart';
export 'parsers/kugoulive_directory.dart' hide kugouliveAnsweredAt;
export 'parsers/kugoulive_failure.dart';
export 'parsers/kugoulive_json.dart' hide kugouliveHostIs;
export 'parsers/kugoulive_room_parser.dart';

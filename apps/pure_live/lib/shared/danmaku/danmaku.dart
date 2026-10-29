/// Danmaku as a file: one entry shape, the formats a save can take, the
/// writers for each, and the choice of which formats to write.
///
/// The live renderer's session lives in `media_core_danmaku`; this module is
/// what sits between a media timeline and the files that outlive it — a
/// recording's chat, a downloaded video's sidecar, a fetched platform track.
library;

export 'package:pure_live/shared/danmaku/danmaku_entry.dart';
export 'package:pure_live/shared/danmaku/danmaku_files.dart';
export 'package:pure_live/shared/danmaku/danmaku_format.dart';
export 'package:pure_live/shared/danmaku/danmaku_save_formats.dart';
export 'package:pure_live/shared/danmaku/formats/formats.dart';

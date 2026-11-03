/// The recording centre: the engine that writes a session, the tasks and
/// settings it stores, the library of what it filed on disk, and the page the
/// viewer drives it from. Another module that records through this engine — the
/// IPTV one does — imports this barrel rather than reaching into the files, and
/// cuts the shared tree down to its own takes with the library pane's platform
/// scope.
library;

export 'data/recorder_library_filter.dart';
export 'data/recorder_search_handoff.dart';
export 'data/recording_covers.dart';
export 'data/recording_library.dart';
export 'data/recording_preview.dart';
export 'data/recording_repository.dart';
export 'data/recording_settings.dart';
export 'data/recording_task.dart';
export 'engine/recorder_engine.dart';
export 'engine/recording_chat_writer.dart';
export 'engine/recording_monitor.dart';
export 'engine/stream_resolver.dart';
export 'pages/recorder_library_pane.dart';
export 'pages/recorder_page.dart';

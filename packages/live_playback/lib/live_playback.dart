/// Live playback orchestration for Pure Live.
///
/// A `PlaybackSession` takes a resolved room or video, drives a [PlayerHandle]
/// from the media kernel, schedules lease renewals, classifies failures and
/// walks the recovery ladder (same line → next line → next quality → refresh →
/// give up), carries the room's chat and knows what a thumbnail presentation
/// does to it. `PlaybackSessionCoordinator` keeps several sessions (windows) in
/// order and decides which one is audible. `PlaybackService` ties the
/// coordinators together behind one intent API and one state snapshot.
///
/// Presentation *mechanics* — fullscreen, the system PiP window, the in-app
/// floating window — belong to `media_core` and its capability packages; this
/// package owns the policy around them (what the viewer allowed, how a device
/// lays a video out, where a small window was left) and never opens an OS
/// window itself.
library;

import 'package:media_core/kernel/library.dart' show PlayerHandle;
import 'package:media_core/kernel/player_handle.dart' show PlayerHandle;
import 'package:media_core/media_core.dart' show PlayerHandle;

export 'src/background/background_playback_manager.dart';
// Configuration
export 'src/config/hive_window_preference_store.dart';
export 'src/config/playback_config.dart';
export 'src/config/window_preference_store.dart';
// Coordination
export 'src/coordinator/playback_session_coordinator.dart';
// Engine seam
export 'src/engine/playback_engine.dart';
// Experiences
export 'src/feed/feed_playback_manager.dart';
// Models
export 'src/model/content_type.dart';
export 'src/model/layout_strategy.dart';
export 'src/model/playback_event.dart';
export 'src/model/playback_failure.dart';
export 'src/model/playback_metadata.dart';
export 'src/model/playback_state.dart';
export 'src/model/playback_system_state.dart';
export 'src/multiview/multi_view_manager.dart';
export 'src/notifications/playback_notifications.dart';
// Orchestration
export 'src/orchestration/playback_orchestrator.dart';
export 'src/playback_service.dart';
// Presentation
export 'src/presentation/in_place_presentation_adapter.dart';
export 'src/presentation/playback_presentation.dart';
export 'src/presentation/window_geometry.dart';
export 'src/presentation/window_preference_manager.dart';
export 'src/presentation/window_sizing_engine.dart';
// Sessions
export 'src/session/lease_scheduler.dart';
export 'src/session/playback_session.dart';
export 'src/session/quality_selector.dart';

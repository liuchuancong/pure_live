import 'dart:async' show unawaited;

import 'package:media_core/media_core.dart';

/// Silences a handle the moment its page lets it go: mute first — it takes
/// effect at once — then pause.
///
/// A release is queued behind whatever the playback is doing (an open still
/// fetching a dead address takes its whole budget), and the picture must not
/// be heard over the page the viewer returned to while that queue drains. Both
/// calls are fire-and-forget: a handle already being released is silent by
/// definition, so a refusal needs no answer.
void silencePlayer(PlayerHandle handle) {
  unawaited(() async {
    try {
      await handle.setMute(muted: true);
    } on Object {
      // Already gone.
    }
    try {
      await handle.pause();
    } on Object {
      // Already gone.
    }
  }());
}

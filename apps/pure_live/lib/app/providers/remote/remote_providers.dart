import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/remote/playback_remote.dart';

export 'package:pure_live/shared/remote/playback_remote.dart';
export 'package:pure_live/shared/remote/playback_target.dart';

/// The LAN playback receiver: one per process, created stopped. The settings
/// pane starts and stops it; playback pages register and unregister their
/// targets as they come and go.
final PlaybackRemote playbackRemote = PlaybackRemote();

/// The receiver for provider readers. The receiver is a ChangeNotifier, so
/// the provider listens to it and invalidates itself on every notify — the
/// status below re-reads, and pages watching the status follow.
final Provider<PlaybackRemote> playbackRemoteProvider = Provider<PlaybackRemote>((ref) {
  void changed() => ref.invalidateSelf();
  playbackRemote.addListener(changed);
  ref.onDispose(() => playbackRemote.removeListener(changed));
  return playbackRemote;
});

/// The pane's view of the receiver: running, address, port, code and the
/// paired count, in one record.
typedef RemoteStatus = ({bool running, String url, String code, int paired});

final Provider<RemoteStatus> playbackRemoteStatus = Provider<RemoteStatus>((ref) {
  final remote = ref.watch(playbackRemoteProvider);
  return (running: remote.running, url: remote.url, code: remote.code, paired: remote.pairedCount);
});

/// Starts the receiver with the browser page's words read from the app's
/// translations; [t] must come from a context under the translator.
Map<String, String> remotePageLabels(Translations t) => {
  'remote_control_title': t.settings.remoteTitle,
  'remote_control_pair': t.settings.remotePair,
  'remote_control_code': t.settings.remoteCodeHint,
  'remote_control_link': t.settings.remoteLinkHint,
  'remote_control_send': t.settings.remoteSend,
  'remote_control_unpair': t.settings.remoteUnpair,
  'remote_control_idle': t.settings.remoteIdle,
  'remote_control_failed': t.settings.remoteFailed,
  'remote_control_paired': t.settings.remotePaired,
  'remote_control_ok': t.settings.remoteOk,
  'remote_control_text': t.settings.remoteTextSend,
  'remote_control_text_hint': t.settings.remoteTextHint,
  'play': t.settings.remotePlay,
  'pause': t.settings.remotePause,
  'refresh': t.settings.remoteRefresh,
  'previous': t.settings.remotePrevious,
  'next': t.settings.remoteNext,
  'volume': t.settings.remoteVolume,
  'mute': t.settings.remoteMute,
  'fullscreen': t.settings.remoteFullscreen,
  'danmaku': t.settings.remoteDanmaku,
  'back': t.settings.remoteBack,
  'home': t.settings.remoteHome,
};

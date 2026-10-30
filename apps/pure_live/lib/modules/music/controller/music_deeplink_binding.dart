import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/modules/music/controller/music_deeplink.dart';

/// Delivers `lxmusic://` links from the operating system to the music
/// dispatcher (see [MusicDeeplinkBinding] below).
///
/// The OS hands the app one link at cold start and any number while running;
/// app_links folds both into one stream, which this binding forwards to
/// `handleMusicDeeplink`. A failed link logs — there is no window to show a
/// toast in yet when the app was launched by the link, and the dispatcher's
/// own errors are already user-shaped strings.
final class MusicDeeplinkBinding {
  /// Creates the binding; the ref lives for the process (the app root starts
  /// this once and never disposes it).
  MusicDeeplinkBinding(this._ref);

  final Ref _ref;
  StreamSubscription<Uri>? _links;

  /// Arms the listener. Safe to call again; the first call wins.
  void start() {
    _links ??= AppLinks().uriLinkStream.listen(
      _handle,
      onError: (Object error) {
        appLog
            .forCategory('music.deeplink')
            .warning('the link stream failed', fields: {'error': '$error'});
      },
    );
  }

  Future<void> _handle(Uri link) async {
    final message = await handleMusicDeeplink(_ref, link.toString());

    if (message != null) {
      appLog
          .forCategory('music.deeplink')
          .warning('the link was rejected', fields: {'reason': message});
    }
  }

  /// Releases the stream; the process root calls this on shutdown only.
  void dispose() {
    unawaited(_links?.cancel());
    _links = null;
  }
}

/// The process-wide deeplink binding, started by the app root.
final musicDeeplinkBindingProvider = Provider<MusicDeeplinkBinding>((ref) {
  final binding = MusicDeeplinkBinding(ref);
  ref.onDispose(binding.dispose);
  return binding;
});

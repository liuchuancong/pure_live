import 'dart:async' show TimeoutException, unawaited;

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveLinkResolver;
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/routing/navigation/route_names.dart';
import 'package:pure_live/app/routing/router/app_router.dart' show RoomRoute, appRouterProvider;
import 'package:pure_live/app/windows/context/app_window_context.dart' show appWindowContextProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/toolbox/toolbox_controllers.dart' show LinkToolController;
import 'package:pure_live/shared/remote/playback_remote.dart';
import 'package:pure_live/shared/remote/playback_target.dart';

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

/// One share link's resolve budget: per site and whole walk, the toolbox
/// pane's own numbers — a phone's patience is the same.
const Duration _remoteLinkPerSite = Duration(seconds: 12);
const Duration _remoteLinkBudget = Duration(seconds: 12);

/// Installs the receiver's app-level seams once, on the main window only:
/// the scope revision that invalidates queued input on a route change, the
/// fallback target a phone lands on when no playback page is up (back and
/// home through the app's own navigation, its confirmations included), and
/// the share-link walk that opens a resolved room. Non-main windows read
/// nothing: the receiver is started from the main window's settings.
///
/// The body reads this window's context and router, so `AppWindowRoot`
/// overrides the provider into its scope: riverpod mounts a provider no
/// scope overrides in the shared root container, where those reads throw.
void startRemoteRuntime(Ref ref) {
  if (!ref.watch(appWindowContextProvider).isMain) return;
  final router = ref.watch(appRouterProvider);
  var revision = 0;
  void touched() => revision++;
  router.routerDelegate.addListener(touched);
  ref.onDispose(() {
    router.routerDelegate.removeListener(touched);
    playbackRemote.scopeRevision = null;
    playbackRemote.applicationTarget = null;
    playbackRemote.onLink = null;
  });
  playbackRemote.scopeRevision = () => revision;
  // Lowest priority by construction: a registered playback page's target
  // wins while one is available, and this answers only over the shell.
  playbackRemote.applicationTarget = RemotePlaybackTarget(
    available: () {
      final state = WidgetsBinding.instance.lifecycleState;
      return state == null || state == AppLifecycleState.resumed;
    },
    snapshot: () => const {
      'scope': 'application',
      'commands': ['back', 'home'],
    },
    execute: (command, _) async {
      // The app's own back: the root navigator's maybePop, so the shell's
      // confirmations (a TV's exit ask, a room's panels) stay in charge.
      if (command == 'back') {
        final navigator = rootNavigatorKey.currentState;
        if (navigator == null) return false;
        return await navigator.maybePop();
      }
      if (command == 'home') {
        router.go(RouteNames.popular);
        return true;
      }
      return false;
    },
  );
  playbackRemote.onLink = (text, authorized) async {
    if (!authorized()) return false;
    final uri = LinkToolController.linkUriOf(text);
    if (uri == null) return false;
    String? platform;
    String? roomId;
    final budget = Stopwatch()..start();
    for (final site in ref.read(sitesProvider).all) {
      if (!authorized() || budget.elapsed >= _remoteLinkBudget) return false;
      final resolver = site.capability<LiveLinkResolver>();
      if (resolver == null) continue;
      try {
        final canonical = await resolver.resolve(uri).timeout(_remoteLinkPerSite);
        if (!authorized()) return false;
        canonical.match((_) {}, (url) {
          final segments = url.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
          final id = segments.isEmpty ? '' : segments.last.trim();
          if (id.isNotEmpty) {
            platform = site.manifest.id;
            roomId = id;
          }
        });
      } on TimeoutException {
        // Only a site that took the link can time out; the rest refuse at
        // once, so the timeout names the network, not the platform.
      } on Object {
        // A resolver answers failures as lefts; anything thrown is the same
        // kind of trouble, and the walk must not strand on it.
      }
      if (platform != null) break;
    }
    if (platform == null || roomId == null || !authorized()) return false;
    unawaited(router.push(RoomRoute(platform: platform!, roomId: roomId!).location));
    return true;
  };
}

/// The provider form of [startRemoteRuntime]; `AppWindowRoot` overrides it
/// into the per-window scope.
final Provider<void> remoteRuntimeProvider = Provider<void>(startRemoteRuntime);

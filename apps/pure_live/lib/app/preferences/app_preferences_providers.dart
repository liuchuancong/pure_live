import 'dart:async';

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';

/// The booted [AppPreferencesStore], overridden in the `ProviderScope` at
/// start-up — the store owns an open box, so nothing here can invent one.
final appPreferencesStoreProvider = Provider<AppPreferencesStore>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The persisted general preferences — general, refresh, page, navigation,
/// proxy, loading and room-card choices — the single source every knob reads.
///
/// The store applies a change to its in-memory value before it is durable, so
/// this provider notifies immediately; the write that follows never comes
/// back as a second change.
final appPreferencesProvider = NotifierProvider<AppPreferencesNotifier, AppPreferences>(
  AppPreferencesNotifier.new,
);

/// Reads the persisted preferences and writes every change back through the
/// store.
final class AppPreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() {
    final store = ref.watch(appPreferencesStoreProvider);
    final subscription = store.changes.listen((preferences) => state = preferences);
    ref.onDispose(subscription.cancel);
    return store.value;
  }

  /// Applies [transform] to the preferences; the returned future completes
  /// once the change is durable.
  Future<void> update(AppPreferences Function(AppPreferences preferences) transform) =>
      ref.read(appPreferencesStoreProvider).update(transform);

  /// What the boot-time load found wrong, empty when it found nothing.
  List<AppPreferencesFailure> get failures => ref.read(appPreferencesStoreProvider).failures;
}

/// The shell branches the chromes render, in the order the user arranged.
final visibleShellBranchesProvider = Provider<List<ShellBranch>>(
  (ref) => visibleShellBranches(ref.watch(appPreferencesProvider)),
);

/// How a feed's first-load placeholder is drawn.
final loadingStyleProvider = Provider<LoadingStyle>((ref) => ref.watch(appPreferencesProvider).loadingStyle);

/// The room card's drawn choices — radius, pills and cover shape.
final roomCardStyleProvider = Provider<RoomCardStyle>((ref) {
  final preferences = ref.watch(appPreferencesProvider);
  return RoomCardStyle(
    cornerRadius: preferences.roomCardCornerRadius,
    aspect: preferences.roomCardAspect,
    showPlatform: preferences.roomCardShowPlatform,
    showAudience: preferences.roomCardShowAudience,
    showAnchor: preferences.roomCardShowAnchor,
  );
});

/// The room card's drawn choices, resolved once per change.
final class RoomCardStyle {
  /// The style over the given fields.
  const new({
    required this.cornerRadius,
    required this.aspect,
    required this.showPlatform,
    required this.showAudience,
    required this.showAnchor,
  });

  /// The card's corner radius, in logical pixels.
  final double cornerRadius;

  /// The cover's shape.
  final RoomCardCoverAspect aspect;

  /// Whether the platform pill draws.
  final bool showPlatform;

  /// Whether the audience and status pills draw.
  final bool showAudience;

  /// Whether the anchor line (avatar and name) draws.
  final bool showAnchor;
}

/// The foreground feed refresh answers: how often a list refreshes itself,
/// and how long away counts as worth a refresh on resume.
final feedRefreshProvider = Provider<FeedRefreshSettings>((ref) {
  final preferences = ref.watch(appPreferencesProvider);
  return FeedRefreshSettings(
    interval: preferences.autoRefreshMinutes <= 0
        ? null
        : Duration(minutes: preferences.autoRefreshMinutes),
    resumeThreshold: Duration(minutes: preferences.refreshResumeThresholdMinutes.clamp(0, 24 * 60)),
    refreshOnResume: preferences.refreshOnResume,
  );
});

/// The feed refresh answers, resolved once per change.
final class FeedRefreshSettings {
  /// The settings over the given fields.
  const new({required this.interval, required this.resumeThreshold, required this.refreshOnResume});

  /// How often a visible feed refreshes itself; null when the interval
  /// preference is off.
  final Duration? interval;

  /// How long away counts as worth refreshing for on resume.
  final Duration resumeThreshold;

  /// Whether a feed refreshes on resume at all.
  final bool refreshOnResume;
}

/// The one way out of the app the countdown close uses.
///
/// The desktop composition root overrides this with the shell's own quit —
/// the graceful path that runs the app's shutdown (storage, log) and then
/// destroys the window. Everywhere else the framework's navigator pop ends
/// the activity.
final appQuitProvider = Provider<Future<void> Function()>((ref) => SystemNavigator.pop);

/// The foreground transitions a feed refreshes on.
///
/// One host widget (the `AppPreferencesHost` mounted once above the
/// navigator) feeds it; the list pages subscribe to
/// [AppResumeSignals.resumes] and refresh when the away time clears their
/// threshold.
final appResumeSignalsProvider = Provider<AppResumeSignals>((ref) {
  final signals = AppResumeSignals();
  ref.onDispose(signals.dispose);
  return signals;
});

/// The app's lifecycle, reduced to "resumed after away for D".
final class AppResumeSignals {
  /// The signals hub.
  new();

  final StreamController<Duration> _controller = StreamController<Duration>.broadcast();
  DateTime? _pausedAt;

  /// Emits one event per foreground return, carrying the away time.
  Stream<Duration> get resumes => _controller.stream;

  /// Feeds a lifecycle transition in; the host widget calls this.
  void handle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _pausedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt != null && !_controller.isClosed) {
          _controller.add(DateTime.now().difference(pausedAt));
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// Releases the stream.
  void dispose() {
    unawaited(_controller.close());
  }
}

/// Mounts the lifecycle host and the countdown close above the navigator —
/// the one widget the app shell hangs its timers on.
final class AppPreferencesHost extends ConsumerStatefulWidget {
  /// Hosts the app's preference-driven timers over [child].
  const new({required this.child, super.key});

  /// The app below.
  final Widget child;

  @override
  ConsumerState<AppPreferencesHost> createState() => _AppPreferencesHostState();
}

final class _AppPreferencesHostState extends ConsumerState<AppPreferencesHost> with WidgetsBindingObserver {
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appResumeSignalsProvider).handle(state);
  }

  @override
  Widget build(BuildContext context) {
    // Re-arms the countdown whenever the countdown preferences move — and
    // does nothing (the timer keeps running) while they hold still.
    ref.listen(appPreferencesProvider, (previous, next) {
      if (previous == null) {
        return;
      }
      if (previous.countdownCloseEnabled != next.countdownCloseEnabled ||
          previous.countdownCloseMinutes != next.countdownCloseMinutes) {
        _armCountdown();
      }
    });
    return widget.child;
  }

  /// Arms (or disarms) the exit countdown from the current preferences. The
  /// countdown runs from the moment it is armed — launch or the flip of the
  /// switch — which is the reference's own semantics.
  void _armCountdown() {
    _countdown?.cancel();
    _countdown = null;
    final preferences = ref.read(appPreferencesProvider);
    if (!preferences.countdownCloseEnabled || preferences.countdownCloseMinutes <= 0) {
      return;
    }
    _countdown = Timer(Duration(minutes: preferences.countdownCloseMinutes), () {
      unawaited(ref.read(appQuitProvider)());
    });
  }
}

/// Applies a chrome's destination selection: navigates to the branch and
/// remembers it as the one the app was left on — what restore-last-tab
/// launches read back.
void goShellBranch(WidgetRef ref, StatefulNavigationShell navigationShell, String id) {
  final branch = ShellBranch.fromId(id);
  navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  if (ref.read(appPreferencesProvider).lastBranchId != branch.name) {
    unawaited(ref.read(appPreferencesProvider.notifier).update((preferences) => preferences.copyWith(lastBranchId: branch.name)));
  }
}

/// Keeps the shell's current branch a visible one.
///
/// Page settings can hide the branch the viewer is standing on from the
/// settings page above the shell; the next time the chrome renders, its
/// destinations no longer contain the selection. This guard notices and
/// walks to the first visible branch, so a hidden branch is never home.
final class ShellBranchGuard extends ConsumerStatefulWidget {
  /// Guards [child] around [navigationShell].
  const new({required this.child, required this.navigationShell, super.key});

  /// The dispatched shell.
  final Widget child;

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellBranchGuard> createState() => _ShellBranchGuardState();
}

final class _ShellBranchGuardState extends ConsumerState<ShellBranchGuard> {
  @override
  void initState() {
    super.initState();
    _redirectIfHidden();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appPreferencesProvider, (_, _) => _redirectIfHidden());
    return widget.child;
  }

  void _redirectIfHidden() {
    final current = ShellBranch.at(widget.navigationShell.currentIndex);
    if (ref.read(visibleShellBranchesProvider).contains(current)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final visible = ref.read(visibleShellBranchesProvider);
      if (!visible.contains(ShellBranch.at(widget.navigationShell.currentIndex))) {
        goShellBranch(ref, widget.navigationShell, visible.first.name);
      }
    });
  }
}

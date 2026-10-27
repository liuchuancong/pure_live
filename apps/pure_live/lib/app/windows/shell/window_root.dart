import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show DesktopShell, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show
        DesktopFocus,
        DesktopInvalidated,
        DesktopMessage,
        DesktopMessageBus,
        DesktopNavigate,
        DesktopWindowRecord,
        MultiViewWindowHost;
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show PureLiveApp;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/app/routing/navigation/root_navigator.dart' show rootNavigatorKey;
import 'package:pure_live/app/routing/navigation/route_observer.dart' show routeObserverProvider;
import 'package:pure_live/app/routing/router/app_router.dart' show PopularRoute, appRouterProvider, buildAppRouter;
import 'package:pure_live/app/windows/context/app_window_context.dart' show AppWindowContext, appWindowContextProvider;
import 'package:pure_live/app/windows/shell/desktop_shell_wiring.dart' show startDesktopShell;
import 'package:pure_live/features/room/room.dart';

/// One OS window's root.
///
/// The outer container is shared by every view; this widget adds a child scope
/// that overrides everything which must not be shared: the view identity, its
/// host, its router, and the room/playback stack. App-level services stay in
/// the parent container, so settings and follows still have one source.
final class AppWindowRoot extends StatefulWidget {
  /// A root for [viewId].
  const AppWindowRoot({
    required this.viewId,
    required this.role,
    required this.initialRoute,
    this.businessKey,
    super.key,
  });

  /// Builds from a registry record.
  factory AppWindowRoot.fromRecord(DesktopWindowRecord record) => AppWindowRoot(
    viewId: record.viewId,
    role: record.role,
    businessKey: record.businessKey,
    initialRoute: record.route ?? const PopularRoute().location,
  );

  /// The plugin's public view id.
  final int viewId;

  /// What this window is for.
  final WindowRole role;

  /// The business identity when the window shows one.
  final String? businessKey;

  /// The router's first location.
  final String initialRoute;

  @override
  State<AppWindowRoot> createState() => _AppWindowRootState();
}

final class _AppWindowRootState extends State<AppWindowRoot> {
  late final MultiViewWindowHost _host = MultiViewWindowHost(viewId: widget.viewId, role: widget.role);
  late final AppWindowContext _context = AppWindowContext(
    viewId: widget.viewId,
    role: widget.role,
    host: _host,
    businessKey: widget.businessKey,
    initialRoute: widget.initialRoute,
  );
  // The primary keeps the process-wide key dialogs and the shell reach; every
  // other view gets its own. Cached so a rebuild cannot swap the key under a
  // live router.
  late final GlobalKey<NavigatorState> _routerKey = _context.isMain ? rootNavigatorKey : GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appWindowContextProvider.overrideWithValue(_context),
        windowHostProvider.overrideWithValue(_host),
        desktopWindowHostProvider.overrideWith((ref) => _host),
        isPrimaryWindowProvider.overrideWithValue(_context.isMain),
        windowIdProvider.overrideWithValue('${_context.viewId}'),
        // One observer per window: a navigator observer can belong to a single
        // navigator, and every window has its own.
        routeObserverProvider.overrideWith((ref) => RouteObserver<ModalRoute<void>>()),
        appRouterProvider.overrideWith((ref) {
          final router = buildAppRouter(
            initialLocation: _context.initialRoute,
            navigatorKey: _routerKey,
            observer: ref.watch(routeObserverProvider),
          );
          ref.onDispose(router.dispose);
          return router;
        }),
        maximizedProvider.overrideWith(MaximizedController.new),
        windowSizeProvider.overrideWith(WindowSizeController.new),
        playerKernelProvider.overrideWith(createPlayerKernel),
        presentationDriverProvider.overrideWith(createPresentationDriver),
        fullscreenDriverProvider.overrideWith(createFullscreenDriver),
        windowsPipWindowProvider.overrideWith(createWindowsPipWindow),
        pipDriverProvider.overrideWith(createPipDriver),
        roomPlaybackStandbyProvider.overrideWith(createRoomPlaybackStandby),
        roomProvider.overrideWith(RoomController.new),
        roomChatProvider.overrideWith(RoomChatController.new),
        roomPlaylistProvider.overrideWith(RoomPlaylistController.new),
        roomRefreshRateProvider.overrideWith(RoomRefreshRateController.new),
        roomSlowProvider.overrideWith(RoomSlowController.new),
        roomSuperChatsProvider.overrideWith(RoomSuperChatController.new),
        sleepTimerProvider.overrideWith(SleepTimerController.new),
        roomPresentationProvider.overrideWith(RoomPresentationController.new),
        castControllerProvider.overrideWith(createCastController),
        // A room window's leave verb is closing its own window (the provider's
        // documented host override): the back button and the menu's close stop
        // this room instead of pushing the primary's popular page, and the
        // floatPlay handoff never crosses into the primary's scope — the
        // overlay there cannot see this window's container.
        roomLeaveProvider.overrideWith((ref) {
          if (ref.watch(appWindowContextProvider).isMain) return null;
          final host = ref.watch(windowHostProvider);
          if (host == null) return null;
          return host.close;
        }),
        barrageProvider.overrideWith((ref) {
          ref.watch(roomProvider);
          return ref.read(roomProvider.notifier).barrage;
        }),
      ],
      child: _WindowMessages(
        child: _MainWindowShell(
          role: widget.role,
          child: PureLiveApp(showStartupSplash: _context.isMain),
        ),
      ),
    );
  }
}

/// Routes the typed commands other windows address to this one.
///
/// The subscription is per view, registered after the first frame so the
/// plugin's per-view stream exists. A closed window's stream is disposed by
/// the plugin, and `dispose` cancels the subscription either way.
final class _WindowMessages extends ConsumerStatefulWidget {
  const _WindowMessages({required this.child});

  final Widget child;

  @override
  ConsumerState<_WindowMessages> createState() => _WindowMessagesState();
}

final class _WindowMessagesState extends ConsumerState<_WindowMessages> {
  StreamSubscription<DesktopMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscription = DesktopMessageBus.instance.onDirect(context).listen(_handle);
    });
  }

  void _handle(DesktopMessage message) {
    if (!mounted) return;
    switch (message) {
      case DesktopNavigate(:final location):
        ref.read(appRouterProvider).go(location);
      case DesktopFocus():
        unawaited(ref.read(windowHostProvider)?.show() ?? Future<void>.value());
      case DesktopInvalidated():
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Starts the primary window's shell once, after the first frame.
///
/// Secondary windows have no shell: their close path releases only their own
/// page and player, and the primary's quit path dismisses them explicitly.
final class _MainWindowShell extends ConsumerStatefulWidget {
  const _MainWindowShell({required this.role, required this.child});

  final WindowRole role;
  final Widget child;

  @override
  ConsumerState<_MainWindowShell> createState() => _MainWindowShellState();
}

final class _MainWindowShellState extends ConsumerState<_MainWindowShell> {
  DesktopShell? _shell;

  @override
  void initState() {
    super.initState();
    if (widget.role == WindowRole.main) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
    }
  }

  Future<void> _start() async {
    try {
      _shell = await startDesktopShell(ref);
    } on Object catch (error, stackTrace) {
      appLog.forCategory('shell').error('the desktop shell could not start', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    unawaited(_shell?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

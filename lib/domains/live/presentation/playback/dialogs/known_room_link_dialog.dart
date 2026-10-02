import 'dart:async';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/live/presentation/playback/dialogs/live_dlna_dialog.dart';
import 'package:pure_live/core/utils/action_scope.dart';
import 'package:pure_live/domains/live/data/direct_link_flow.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

/// One route-owned action shared by the player's menu and control bar.
class KnownRoomLinkDialog extends StatefulWidget {
  const KnownRoomLinkDialog({
    super.key,
    required this.room,
    required this.cast,
    required this.flow,
    required this.isCurrentRoom,
    required this.notify,
    this.sourceRoute,
    this.openCast,
  });

  final LiveRoom room;
  final bool cast;
  final LiveDirectLinkFlow flow;
  final bool Function() isCurrentRoom;
  final void Function(String) notify;
  final Route<dynamic>? sourceRoute;
  final Future<void> Function(String)? openCast;
  static final _active = <NavigatorState, Future<void>>{};

  /// 播放页菜单/控制栏发起：按已知直播间解析播放直链。
  static Future<void> getPlayUrlByRoomId({
    required BuildContext context,
    required LiveRoom liveroom,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
  }) => _showKnownRoomAction(
    context: context,
    liveroom: liveroom,
    cast: false,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
  );

  /// 播放页菜单/控制栏发起：按已知直播间投屏。
  static Future<void> castPlayUrlByRoomId({
    required BuildContext context,
    required LiveRoom liveroom,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) => _showKnownRoomAction(
    context: context,
    liveroom: liveroom,
    cast: true,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
    openCast: openCast,
  );

  /// 这两个入口原先挂在数据层的 LiveUrlTool 上，却要弹对话框——
  /// 属于页面动作，随对话框一起留在 presentation。
  static Future<void> _showKnownRoomAction({
    required BuildContext context,
    required LiveRoom liveroom,
    required bool cast,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) {
    if (!context.mounted) return Future.value();
    final roomId = (liveroom.roomId ?? '').trim();
    final platform = (liveroom.platform ?? '').trim().toLowerCase();
    final showNotice = notify ?? ((String key) => ToastUtil.show(i18n(key)));
    if (roomId.isEmpty || platform.isEmpty) {
      showNotice('toolbox_empty_link');
      return Future.value();
    }
    if (!Sites.isSupported(platform)) {
      showNotice('toolbox_parse_failed');
      return Future.value();
    }
    return KnownRoomLinkDialog.show(
      context: context,
      liveroom: LiveRoom(roomId: roomId, platform: platform),
      cast: cast,
      flow: LiveDirectLinkFlow(siteFor: siteFor),
      isCurrentRoom: isCurrentRoom ?? (() => true),
      notify: showNotice,
      openCast: openCast,
    );
  }

  static Future<void> show({
    required BuildContext context,
    required LiveRoom liveroom,
    required bool cast,
    required LiveDirectLinkFlow flow,
    required bool Function() isCurrentRoom,
    required void Function(String) notify,
    Future<void> Function(String)? openCast,
  }) {
    if (!context.mounted || !isCurrentRoom()) return Future.value();
    final navigator = Navigator.of(context, rootNavigator: true);
    final current = _active[navigator];
    if (current != null) return current;
    final done = Completer<void>();
    _active[navigator] = done.future;
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => KnownRoomLinkDialog(
        room: liveroom,
        cast: cast,
        flow: flow,
        isCurrentRoom: isCurrentRoom,
        notify: notify,
        sourceRoute: ModalRoute.of(context),
        openCast: openCast,
      ),
    );
    Future<void> push() async {
      try {
        await navigator.push(route);
      } catch (_) {
        if (context.mounted && isCurrentRoom()) notify('toolbox_get_url_failed');
      } finally {
        if (identical(_active[navigator], done.future)) _active.remove(navigator);
        done.complete();
      }
    }

    unawaited(push());
    return done.future;
  }

  @override
  State<KnownRoomLinkDialog> createState() => _KnownRoomLinkDialogState();
}

class _KnownRoomLinkDialogState extends State<KnownRoomLinkDialog> {
  late final ActionScope _scope;
  final ScrollController _scrollController = ScrollController();
  Route<dynamic>? _route;
  Route<dynamic>? _child;
  NavigatorState? _navigator;
  bool _finishing = false;
  String? _title;
  VoidCallback? _cancelChoice;
  Widget _body = const Padding(
    padding: EdgeInsets.all(20),
    child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator())),
  );

  @override
  void initState() {
    super.initState();
    _scope = ActionScope(
      ownerAlive: () =>
          mounted &&
          widget.isCurrentRoom() &&
          (widget.sourceRoute?.isActive ?? true) &&
          ((_route?.isCurrent ?? false) || (_child?.isCurrent ?? false)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _navigator = Navigator.of(context);
  }

  Future<void> _run() async {
    try {
      await widget.flow.run(
        liveroom: widget.room,
        scope: _scope,
        notify: widget.notify,
        chooseQuality: (items) =>
            _choose<LivePlayQuality>(i18n('toolbox_select_quality'), items, (item, _) => item.quality),
        chooseLine: (items) => _choose<String>(
          i18n('toolbox_select_line'),
          items,
          (_, index) => i18n('toolbox_line', args: {'index': '${index + 1}'}),
          subtitle: (url) => url,
        ),
        useUrl: widget.cast ? _cast : null,
      );
    } on ActionCancelled {
      // The source room, route or user intent no longer owns this result.
    } catch (_) {
      if (_scope.isActive) widget.notify('toolbox_get_url_failed');
    } finally {
      _finish();
    }
  }

  Future<T?> _choose<T>(
    String title,
    List<T> items,
    String Function(T, int) label, {
    String Function(T)? subtitle,
  }) async {
    _scope.checkActive();
    final result = Completer<T?>();
    void cancelChoice() {
      if (!result.isCompleted) result.complete();
    }

    _cancelChoice = cancelChoice;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _title = title;
      _body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              key: ValueKey('known-room-choice-$i'),
              title: Text(label(items[i], i), textAlign: TextAlign.center),
              subtitle: subtitle == null
                  ? null
                  : Text(subtitle(items[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                if (result.isCompleted) return;
                if (!_scope.isActive) {
                  _finish();
                  return;
                }
                if (identical(_cancelChoice, cancelChoice)) _cancelChoice = null;
                if (_scrollController.hasClients) _scrollController.jumpTo(0);
                setState(
                  () => _body = const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator())),
                  ),
                );
                result.complete(items[i]);
              },
            ),
        ],
      );
    });
    try {
      return await result.future;
    } finally {
      if (identical(_cancelChoice, cancelChoice)) _cancelChoice = null;
    }
  }

  Future<void> _cast(String url) async {
    _scope.checkActive();
    final openCast = widget.openCast;
    if (openCast != null) {
      await openCast(url);
      return;
    }
    final navigator = _navigator!;
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => LiveDlnaPage(datasource: url),
    );
    _child = route;
    unawaited(
      _scope.cancelToken.whenCancel.then((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      }),
    );
    try {
      await navigator.push(route);
    } finally {
      if (identical(_child, route)) _child = null;
    }
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    _cancelChoice?.call();
    _cancelChoice = null;
    _scope.cancel();
    final route = _route;
    final navigator = _navigator;
    if (!mounted || navigator == null || !navigator.mounted || route == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _cancelChoice?.call();
    _cancelChoice = null;
    _scope.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.vertical - mediaQuery.viewInsets.vertical - 32;
    return Dialog(
      key: const ValueKey('known-room-link-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: availableHeight > 0 ? availableHeight : mediaQuery.size.height,
        ),
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('known-room-link-scroll'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _title ?? i18n(widget.cast ? 'cast_screen' : 'toolbox_get_direct_link'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      _body,
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const ValueKey('known-room-link-cancel'),
                      onPressed: _finish,
                      child: Text(i18n('cancel')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

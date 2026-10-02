import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/action_scope.dart';
import 'package:pure_live/domains/live/data/direct_link_flow.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/data/link/live_url_tool.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

enum ToolBoxAction { jump, directLink }

class ToolBoxController extends GetxController {
  ToolBoxController({
    this.parseLink,
    Future<void> Function(LiveRoom)? openRoom,
    this.obtainLink,
    void Function(String)? notify,
    LiveDirectLinkFlow? directLinkFlow,
    this.actionTimeout = const Duration(seconds: 12),
  }) : _openRoom = openRoom ?? ((room) => AppNavigator.toLiveRoomDetail(liveRoom: room)),
       _directLinkFlow = directLinkFlow ?? LiveDirectLinkFlow(),
       _notify = notify ?? ((key) => ToastUtil.show(i18n(key))) {
    roomJumpToController.addListener(_roomEdited);
    getUrlController.addListener(_urlEdited);
  }

  final Future<List<String>> Function(String)? parseLink;
  final Future<void> Function(LiveRoom) _openRoom;
  final Future<void> Function(String)? obtainLink;
  final LiveDirectLinkFlow _directLinkFlow;
  final Duration actionTimeout;
  final action = Rx<ToolBoxAction?>(null);
  ActionScope? _scope;
  Route<dynamic>? _ownedDialog;
  bool get isBusy => action.value != null;
  final void Function(String) _notify;

  final TextEditingController roomJumpToController = TextEditingController();
  final TextEditingController getUrlController = TextEditingController();
  int _roomRevision = 0;
  int _urlRevision = 0;
  bool _clipboardChecked = false;
  bool _disposed = false;

  void _roomEdited() {
    _roomRevision++;
    if (action.value == ToolBoxAction.jump) cancelAction();
  }

  void _urlEdited() {
    _urlRevision++;
    if (action.value == ToolBoxAction.directLink) cancelAction();
  }

  void cancelAction() => _scope?.cancel();

  Future<void> _runAction(
    String text,
    ToolBoxAction kind,
    BuildContext? context,
    Future<void> Function(String, ActionScope) run,
  ) async {
    if (_disposed || isClosed || isBusy) return;
    text = text.trim();
    if (text.isEmpty) {
      _notify('toolbox_empty_link');
      return;
    }
    final sourceRoute = context == null ? null : ModalRoute.of(context);
    final scope = ActionScope(
      timeout: actionTimeout,
      ownerAlive: () =>
          !_disposed &&
          !isClosed &&
          (context == null || context.mounted) &&
          (sourceRoute == null || sourceRoute.isCurrent || (_ownedDialog?.isCurrent ?? false)),
    );
    _scope = scope;
    action.value = kind;
    try {
      await run(text, scope);
    } on ActionCancelled {
      // Editing, cancelling and leaving are user intent, not failures.
    } catch (_) {
      if (scope.isActive) _notify(kind == ToolBoxAction.jump ? 'toolbox_parse_failed' : 'toolbox_get_url_failed');
    } finally {
      scope.cancel();
      if (identical(_scope, scope)) {
        _scope = null;
        if (!_disposed && !isClosed) action.value = null;
      }
    }
  }

  Future<LiveRoom?> _resolve(String text, ActionScope scope) async {
    final result = await scope.wait(
      () => parseLink?.call(text) ?? LiveUrlTool.parseLiveUrl(text, cancelToken: scope.cancelToken),
    );
    if (result.length != 2 || result.first.trim().isEmpty || !Sites.isSupported(result[1])) {
      _notify('toolbox_parse_failed');
      return null;
    }
    return LiveRoom(
      roomId: result.first,
      platform: result[1],
      title: '',
      cover: '',
      nick: '',
      watching: '',
      avatar: '',
      area: '',
      liveStatus: LiveStatus.live,
      status: true,
      data: '',
      danmakuData: '',
    );
  }

  Future<void> jumpToRoom(String text, {BuildContext? context}) =>
      _runAction(text, ToolBoxAction.jump, context, (text, scope) async {
        final room = await _resolve(text, scope);
        if (room == null) return;
        FocusManager.instance.primaryFocus?.unfocus();
        // Navigation completes when the player route returns, not on a timer.
        await scope.wait(() => _openRoom(room), timed: false);
      });

  Future<void> getPlayUrl(String text, {BuildContext? context}) =>
      _runAction(text, ToolBoxAction.directLink, context, (text, scope) async {
        final obtainLink = this.obtainLink;
        if (obtainLink != null) {
          await scope.wait(() => obtainLink(text));
          return;
        }
        final room = await _resolve(text, scope);
        if (room == null) return;
        if (context == null || !context.mounted) throw const ActionCancelled();
        FocusManager.instance.primaryFocus?.unfocus();
        await _directLinkFlow.run(
          liveroom: room,
          scope: scope,
          chooseQuality: (qualities) => _choose<LivePlayQuality>(
            context,
            scope,
            title: i18n('toolbox_select_quality'),
            items: qualities,
            label: (quality, _) => quality.quality,
          ),
          chooseLine: (urls) => _choose<String>(
            context,
            scope,
            title: i18n('toolbox_select_line'),
            items: urls,
            label: (_, index) => i18n('toolbox_line', args: {'index': '${index + 1}'}),
            subtitle: (url) => url,
          ),
          notify: _notify,
        );
      });

  Future<T?> _choose<T>(
    BuildContext context,
    ActionScope scope, {
    required String title,
    required List<T> items,
    required String Function(T, int) label,
    String Function(T)? subtitle,
  }) async {
    scope.checkActive();
    final navigator = Navigator.of(context, rootNavigator: true);
    var selected = false;
    final route = DialogRoute<T>(
      context: context,
      builder: (dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final maxHeight = (mediaQuery.size.height - mediaQuery.padding.vertical - mediaQuery.viewInsets.vertical - 32)
            .clamp(160.0, double.infinity)
            .toDouble();
        return Dialog(
          key: const ValueKey('toolbox-choice-dialog'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: Theme.of(dialogContext).textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          for (var i = 0; i < items.length; i++)
                            ListTile(
                              title: Text(label(items[i], i), textAlign: TextAlign.center),
                              subtitle: subtitle == null
                                  ? null
                                  : Text(subtitle(items[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                if (!selected && scope.isActive) {
                                  selected = true;
                                  Navigator.of(dialogContext).pop(items[i]);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const ValueKey('toolbox-choice-cancel'),
                      onPressed: () {
                        if (!selected) {
                          selected = true;
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: Text(i18n('cancel')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _ownedDialog = route;
    unawaited(
      scope.cancelToken.whenCancel.then((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      }),
    );
    try {
      return await navigator.push(route);
    } finally {
      if (identical(_ownedDialog, route)) _ownedDialog = null;
    }
  }

  Future<void> autoCheckClipboard({BuildContext? context}) async {
    if (_disposed || isClosed || _clipboardChecked) return;
    _clipboardChecked = true;
    final sourceRoute = context == null ? null : ModalRoute.of(context);
    final roomEmpty = roomJumpToController.text.isEmpty;
    final urlEmpty = getUrlController.text.isEmpty;
    if (!roomEmpty && !urlEmpty) return;
    final roomRevision = _roomRevision;
    final urlRevision = _urlRevision;
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
    if (_disposed ||
        isClosed ||
        (context != null && (!context.mounted || sourceRoute == null || !sourceRoute.isCurrent))) {
      return;
    }
    final text = data?.text;
    if (text == null || !containsSupportedLink(text)) return;

    // A type-and-clear is still an edit: checking only the current text would
    // silently refill a field the user deliberately cleared while we waited.
    final fillRoom = roomEmpty && _roomRevision == roomRevision;
    final fillUrl = urlEmpty && _urlRevision == urlRevision;
    if (fillRoom || fillUrl) {
      if (fillRoom) roomJumpToController.text = text;
      if (fillUrl) getUrlController.text = text;
      Get.snackbar(
        i18n("toolbox_detect_link"),
        i18n("toolbox_auto_fill"),
        snackPosition: SnackPosition.bottom,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(15),
      );
    }
  }

  /// Local detection only; use the same URI extraction as manual parsing.
  static bool containsSupportedLink(String text) => LiveUrlTool.containsSupportedLink(text);

  @override
  void onClose() {
    cancelAction();
    _disposed = true;
    roomJumpToController.removeListener(_roomEdited);
    getUrlController.removeListener(_urlEdited);
    roomJumpToController.dispose();
    getUrlController.dispose();
    super.onClose();
  }
}

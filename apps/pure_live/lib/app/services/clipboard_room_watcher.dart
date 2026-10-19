import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveLinkResolver;
import 'package:pure_live/app/navigation/app_navigator_key.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The clipboard's room links — the reference's 剪贴板口令检测, 3.x always
/// looked and v4 made it an answer.
///
/// The look happens when the app comes back to the foreground, never while a
/// room page owns the screen, and the find is only ever offered: a bottom
/// sheet names the room and its platform and lets the viewer go or leave it.
/// The text that was asked about is not asked twice in one run (and once
/// turned down, the same text does not come back).
final class ClipboardRoomWatcher {
  /// The watcher over the app's provider graph.
  new(this._ref);

  final Ref _ref;
  String _seen = '';
  bool _busy = false;
  AppLifecycleListener? _listener;

  /// Starts watching; idempotent, and [dispose] is required to stop it.
  void start() {
    _listener ??= AppLifecycleListener(onResume: tick);
  }

  /// Looks once — the tests and the settings preview drive it directly.
  Future<void> tick() async {
    if (_busy || !active) {
      return;
    }
    _busy = true;
    final String text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text?.trim() ?? '';
    } on Object {
      _busy = false;
      return;
    }
    if (text.isEmpty || text == _seen || !active) {
      _busy = false;
      return;
    }
    _seen = text;
    final room = await _resolve(text);
    _busy = false;
    if (room == null || !active) {
      return;
    }
    final navigator = appNavigatorKey.currentState;
    // The resolve crossed awaits; the page that owns the screen now is the
    // one the offer may land on — and only when no room page is up.
    if (navigator != null && navigator.mounted && active) {
      await _offer(navigator.context, room);
    }
  }

  /// Watching only makes sense with the switch on; a resolved room must not
  /// interrupt a room page that is already up.
  bool get active => _ref.read(appPreferencesProvider).detectClipboardRooms && !onRoomPage;

  /// Whether a room page owns the screen right now.
  bool get onRoomPage {
    final location = _ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    return location.startsWith('/room');
  }

  /// Stops watching.
  void dispose() {
    _listener?.dispose();
    _listener = null;
  }

  /// The toolbox walk: every site's resolver in turn, the first owner wins;
  /// a bare room id with a known platform prefix reads directly.
  Future<({String site, String roomId, String title})?> _resolve(String text) async {
    final resolvers = _ref
        .read(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveLinkResolver>() != null)
        .toList(growable: false);
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    for (final site in resolvers) {
      final result = await site.capability<LiveLinkResolver>()!.resolve(uri);
      final owned = result.fold((failure) => null, (canonical) => canonical);
      if (owned != null) {
        final roomId = owned.pathSegments.lastWhere((part) => part.isNotEmpty, orElse: () => '');
        if (roomId.isEmpty) {
          continue;
        }
        return (site: site.manifest.id, roomId: roomId, title: roomId);
      }
    }
    return null;
  }

  Future<void> _offer(BuildContext context, ({String site, String roomId, String title}) room) async {
    final t = context.t;
    final locale = Localizations.localeOf(context);
    final names = _ref.read(sitesProvider).registry.getById(room.site)?.manifest.name ?? const {};
    final siteName = names[locale.toLanguageTag()] ?? names[locale.languageCode] ?? names['zh'] ?? room.site;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.clipboard.title, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                t.clipboard.found(site: siteName, room: room.roomId),
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PureButton(
                      key: const ValueKey('clipboard-room-ignore'),
                      label: t.common.ignore,
                      variant: ButtonVariant.ghost,
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PureButton(
                      key: const ValueKey('clipboard-room-go'),
                      label: t.clipboard.go,
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (go == true && context.mounted) {
      unawaited(RoomRoute(siteId: room.site, roomId: room.roomId, roomName: room.roomId).push<void>(context));
    }
  }
}

/// One watcher per process; the shell starts it and stops it with itself.
// riverpod's provider type (ProviderFamily/...autoDispose) is not exported
// by flutter_riverpod, so the variable annotation the lint asks for cannot
// be written.
// ignore: specify_nonobvious_property_types
final clipboardRoomWatcherProvider = Provider.autoDispose<ClipboardRoomWatcher>((ref) {
  final watcher = ClipboardRoomWatcher(ref);
  ref.onDispose(watcher.dispose);
  return watcher;
});

import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';

/// The reference's `detectClipboardRooms`: a room link in the clipboard is
/// offered when the app comes back, never opened on its own.
const String kDetectClipboardRoomsKey = 'app.detectClipboardRooms';

/// Owns the clipboard-room switch.
final class DetectClipboardRoomsController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kDetectClipboardRoomsKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kDetectClipboardRoomsKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The clipboard-room switch.
final detectClipboardRoomsProvider = NotifierProvider<DetectClipboardRoomsController, bool>(
  DetectClipboardRoomsController.new,
);

/// A parsed room link.
typedef ClipboardRoom = ({String platform, String roomId, String label});

/// Reads a supported live-room link out of [text]; null when it is not one.
ClipboardRoom? clipboardRoomOf(String text) {
  final match = RegExp(r'https?://[^\s]+').firstMatch(text);
  if (match == null) return null;
  final uri = Uri.tryParse(match.group(0)!);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  String? first(String hostSuffix) => host == hostSuffix || host.endsWith('.$hostSuffix') ? segments.firstOrNull : null;
  if (host == 'live.bilibili.com') {
    final id = segments.firstOrNull;
    return id == null ? null : (platform: 'bilibili', roomId: id, label: 'Bilibili');
  }
  if (host == 'live.douyin.com') {
    final id = segments.firstOrNull;
    return id == null ? null : (platform: 'douyin', roomId: id, label: '抖音');
  }
  if (host == 'douyu.com' || host.endsWith('.douyu.com')) {
    final id = first('douyu.com');
    return id == null ? null : (platform: 'douyu', roomId: id, label: '斗鱼');
  }
  if (host == 'huya.com' || host.endsWith('.huya.com')) {
    final id = first('huya.com');
    return id == null ? null : (platform: 'huya', roomId: id, label: '虎牙');
  }
  if (host == 'live.kuaishou.com') {
    final index = segments.indexOf('u');
    final id = index >= 0 && index + 1 < segments.length ? segments[index + 1] : null;
    return id == null ? null : (platform: 'kuaishou', roomId: id, label: '快手');
  }
  if (host == 'twitch.tv' || host.endsWith('.twitch.tv')) {
    final id = first('twitch.tv');
    return id == null ? null : (platform: 'twitch', roomId: id, label: 'Twitch');
  }
  if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
    final id = uri.queryParameters['v'] ?? (segments.length > 1 && segments.first == 'live' ? segments[1] : null);
    return id == null ? null : (platform: 'youtube', roomId: id, label: 'YouTube');
  }
  return null;
}

/// Watches the clipboard when the app gains focus; a recognized room link
/// brings one confirmation, never an automatic navigation. Only the primary
/// window asks, or every clone would prompt for the same text.
final class ClipboardRoomWatcher extends ConsumerStatefulWidget {
  /// Watches while [child] is mounted.
  const ClipboardRoomWatcher({required this.child, super.key});

  /// The app below the watcher.
  final Widget child;

  @override
  ConsumerState<ClipboardRoomWatcher> createState() => _ClipboardRoomWatcherState();
}

final class _ClipboardRoomWatcherState extends ConsumerState<ClipboardRoomWatcher> with WidgetsBindingObserver {
  final Set<String> _handled = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (!mounted || !ref.read(detectClipboardRoomsProvider) || !ref.read(isPrimaryWindowProvider)) return;
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on Object {
      return;
    }
    if (text == null || text.trim().isEmpty || !mounted) return;
    final room = clipboardRoomOf(text);
    if (room == null) return;
    final key = '${room.platform}:${room.roomId}';
    if (!_handled.add(key) || !mounted) return;
    final t = context.t;
    final open = await showDsConfirm(
      context: context,
      title: t.settings.clipboardRoomTitle,
      description: t.settings.clipboardRoomDesc(platform: room.label, roomId: room.roomId),
      confirmLabel: t.settings.clipboardRoomOpen,
      cancelLabel: t.common.cancel,
      icon: const DsIcon(DsIcons.clipboard),
    );
    if (open && mounted) {
      await context.push(RoomRoute(platform: room.platform, roomId: room.roomId).location);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

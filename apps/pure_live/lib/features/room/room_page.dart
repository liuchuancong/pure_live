// Module: lib/features/room/room_page.dart
// Purpose: The live room surface: resolves the entry's ContentRef into a ticket, plays it, and keeps it
// alive with the watchdog and ticket swap.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page names no source: it asks the capability registry for the registration the ref's sourceId points
// at and requires a ResolveCapability. Detection of a dying stream is the watchdog's; the physical swap is
// the swapper's; this page only owns the session - sample every couple of seconds, hand the handle over on
// dispose, and show an honest surface when playback cannot start.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../../app/di.dart';
import '../../app/runtime.dart';

/// How often the page samples the player for the watchdog. Fine enough for the
/// 15 second stall window, coarse enough to be free.
const Duration _observeInterval = Duration(seconds: 2);

final class RoomPage extends ConsumerStatefulWidget {
  const RoomPage({required this.roomId, this.contentRef, super.key});

  /// The room identifier exactly as it appeared in the route. Site-specific
  /// formats are a provider concern; the route keeps the raw string.
  final String roomId;

  /// Where the navigation came from. Null for a deep link that named only the route.
  final ContentRef? contentRef;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

final class _RoomPageState extends ConsumerState<RoomPage> {
  PlayerHandle? _handle;
  ResolveCapability? _resolver;
  String? _error;
  bool _loading = false;

  TicketSwapper? _swapper;
  PlaybackWatchdog? _watchdog;
  Timer? _observer;
  String? _watchdogNote;

  ContentSummary? _summary;
  bool _favorite = false;
  DateTime _lastHistoryWrite = DateTime.fromMillisecondsSinceEpoch(0);
  late final PureLiveRuntime _runtime;

  // The play queue: the episode list of the parent, when the entry ref is an
  // episode. Consecutive playback walks it on end; a live room or a top-level
  // vod has an empty queue and never auto-advances.
  List<ContentRef> _queue = const <ContentRef>[];
  int _queueIndex = -1;
  bool _advancedOnce = false;
  bool _ticketIsLive = false;
  ContentRef? _activeRef;

  /// How often the room writes a history row. The service throttles too, but
  /// the file is the unit of durability here: two-second writes would wear it
  /// for nothing, thirty seconds is a crash loss nobody notices.
  static const Duration _historyInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // Captured once: Riverpod forbids ref reads inside dispose, and the exit
    // record below has to reach the runtime exactly there.
    _runtime = ref.read(runtimeProvider);
    _startPlayback();
  }

  Future<void> _startPlayback({ContentRef? refOverride}) async {
    final contentRef = refOverride ?? _activeRef ?? widget.contentRef;
    if (contentRef == null) {
      return;
    }
    _activeRef = contentRef;
    // A new open replaces the old session entirely: leaving a stale handle or
    // watchdog alive would keep sampling a player nobody renders.
    _observer?.cancel();
    await _handle?.dispose();
    _handle = null;
    _swapper = null;
    _watchdog = null;
    final runtime = _runtime;
    setState(() {
      _loading = true;
      _error = null;
      _watchdogNote = null;
    });
    try {
      final registration = runtime.capabilities.all.where((entry) => entry.sourceId == contentRef.sourceId).firstOrNull;
      final provider = registration?.provider;
      if (provider is! ResolveCapability) {
        throw StateError('源 ${contentRef.sourceId} 没有实现取流能力');
      }
      final ticket = await provider.resolve(contentRef);
      final handle = await runtime.media.open(ticket);
      if (!mounted) {
        await handle.dispose();
        return;
      }
      setState(() {
        _resolver = provider;
        _handle = handle;
      });
      _ticketIsLive = ticket.kind == MediaKind.live;
      _startSession(handle, ticket);
      await _loadRoomContext(contentRef, provider);
      await _loadQueue(contentRef, provider);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Loads what the room shows besides video: the summary (from detail when
  /// the source can describe it), whether the room is already a favourite, and
  /// the first history row. None of this may block or break playback - every
  /// failure here just leaves the default surface.
  Future<void> _loadRoomContext(ContentRef contentRef, Object provider) async {
    try {
      if (provider is BrowseCapability) {
        final detail = await provider.detail(contentRef);
        if (mounted) {
          setState(() => _summary = detail.summary);
        }
      }
      final entries = await _runtime.favorites.list();
      final favourite = entries.any((entry) => entry.ref == contentRef);
      await _runtime.history.record(contentRef, Duration.zero, snapshot: _summary);
      if (mounted) {
        setState(() => _favorite = favourite);
      }
    } catch (error) {
      // Room context is decoration; a failing source loses the title card and
      // the history row, not the stream.
      if (mounted) {
        setState(() => _watchdogNote = '房间信息加载失败:$error');
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final contentRef = widget.contentRef;
    final summary = _summary;
    if (contentRef == null) {
      return;
    }
    try {
      if (_favorite) {
        await _runtime.favorites.remove(contentRef);
      } else {
        // Without a summary there is nothing worth listing: a favourite whose
        // card cannot render is a broken row, so the toggle waits for detail.
        if (summary == null) {
          if (mounted) {
            setState(() => _watchdogNote = '房间信息还没读到,稍后再试');
          }
          return;
        }
        await _runtime.favorites.add(contentRef, summary);
      }
      if (mounted) {
        setState(() => _favorite = !_favorite);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _watchdogNote = '收藏操作失败:$error');
      }
    }
  }

  /// Loads the play queue for an episode entry: the parent's detail carries
  /// the sibling list, and the current position is found by content id. A
  /// top-level ref or a missing parent leaves the queue empty.
  Future<void> _loadQueue(ContentRef contentRef, Object provider) async {
    if (contentRef.kind != ContentKind.episode || contentRef.parentId == null) {
      return;
    }
    try {
      if (provider is BrowseCapability) {
        final detail = await provider.detail(
          ContentRef(sourceId: contentRef.sourceId, contentId: contentRef.parentId!, kind: ContentKind.vod),
        );
        final index = detail.children.indexWhere((child) => child.contentId == contentRef.contentId);
        if (mounted) {
          setState(() {
            _queue = detail.children;
            _queueIndex = index;
          });
        }
      }
    } catch (error) {
      // A failed queue load costs the auto-advance only.
      if (mounted) {
        setState(() => _watchdogNote = '连播列表加载失败:$error');
      }
    }
  }

  /// Auto-advance: one step per end event, and only for vod tickets - a live
  /// stream never ends, and a stream whose duration is unknown cannot prove it
  /// ended.
  void _maybeAdvance() {
    if (_ticketIsLive || _loading) {
      return;
    }
    final handle = _handle;
    if (handle == null || !_advancedOnce) {
      return;
    }
    final duration = handle.duration;
    if (duration <= Duration.zero || handle.position < duration - const Duration(milliseconds: 1500)) {
      return;
    }
    final next = _queueIndex + 1;
    if (next >= _queue.length) {
      return;
    }
    setState(() => _queueIndex = next);
    unawaited(_startPlayback(refOverride: _queue[next]));
  }

  /// Wires the keep-alive loop for one opened handle: the swapper fetches and
  /// installs replacements, the watchdog decides when one is needed, and the
  /// timer only feeds samples. Ticket state lives in the watchdog; the swapper
  /// re-reads [TicketSwapper.currentTicket] through the refresh callback.
  void _startSession(PlayerHandle handle, MediaTicket ticket) {
    _swapper = TicketSwapper(handle: handle, replace: _replacementTicket);
    _watchdog = PlaybackWatchdog(
      reportFailure: handle.reportFailure,
      onTicketRefresh: (reason) async {
        final fresh = await _swapper!.swap(reason);
        _watchdog!.ticket = fresh;
      },
      ticket: ticket,
    );
    _observer = Timer.periodic(_observeInterval, (_) => _observe());
  }

  Future<MediaTicket> _replacementTicket(RefreshReason reason) async {
    final resolver = _resolver;
    final current = _swapper?.currentTicket;
    if (resolver == null || current == null) {
      throw StateError('没有可用的换源上下文');
    }
    return resolver.refresh(current, reason);
  }

  Future<void> _observe() async {
    final handle = _handle;
    final watchdog = _watchdog;
    if (handle == null || watchdog == null) {
      return;
    }
    final position = handle.position;
    if (position > Duration.zero) {
      _advancedOnce = true;
    }
    final sample = PlaybackSample(
      at: DateTime.now(),
      phase: handle.isPlaying ? PlaybackPhase.playing : PlaybackPhase.paused,
      position: position,
    );
    try {
      await watchdog.observe(sample);
      final now = DateTime.now();
      if (position > Duration.zero && now.difference(_lastHistoryWrite) >= _historyInterval) {
        _lastHistoryWrite = now;
        await _runtime.history.record(_activeRef!, position, snapshot: _summary);
      }
      _maybeAdvance();
      if (mounted && _watchdogNote != null) {
        setState(() => _watchdogNote = null);
      }
    } catch (error) {
      // A failed swap or a refused refresh is not the end of the session: the
      // stream may still be playing. The note is shown but the handle stays.
      if (mounted) {
        setState(() => _watchdogNote = '保活:$error');
      }
    }
  }

  @override
  void dispose() {
    // Leaving the room ends the session the page owns: the loop stops first so
    // no observe fires on a disposed handle, then the handle closes. No
    // background playback exists yet, so there is no handover to negotiate.
    _observer?.cancel();
    final handle = _handle;
    final contentRef = _activeRef;
    if (handle != null && contentRef != null) {
      final position = handle.position;
      final summary = _summary;
      unawaited(() async {
        try {
          await _runtime.history.record(contentRef, position, snapshot: summary);
        } finally {
          await _runtime.history.flush();
        }
      }());
    }
    _handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handle = _handle;
    return Scaffold(
      appBar: AppBar(
        title: Text('直播间 ${widget.roomId}'),
        actions: <Widget>[
          if (_activeRef != null)
            IconButton(
              icon: Icon(_favorite ? Icons.favorite : Icons.favorite_outline),
              tooltip: _favorite ? '取消收藏' : '收藏',
              onPressed: _toggleFavorite,
            ),
          if (handle != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '手动换源',
              onPressed: () async {
                try {
                  final fresh = await _swapper!.swap(RefreshReason.manual);
                  _watchdog!.ticket = fresh;
                } catch (error) {
                  if (mounted) {
                    setState(() => _watchdogNote = '手动换源失败:$error');
                  }
                }
              },
            ),
        ],
      ),
      body: handle != null
          ? Column(
              children: <Widget>[
                Expanded(child: MediaSurface(handle: handle)),
                if (_watchdogNote != null)
                  Material(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(_watchdogNote!, style: theme.textTheme.bodySmall)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _watchdogNote = null),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: <Widget>[
                  if (_loading) const CircularProgressIndicator(),
                  if (!_loading && _error == null) ...<Widget>[
                    Icon(Icons.play_disabled, size: 64, color: theme.colorScheme.outline),
                    Text('没有可播放的源', style: theme.textTheme.titleMedium),
                    Text(
                      '从首页或搜索结果进入会带上内容引用并直接出票;直接输入链接暂不解析',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                    Text('播放失败', style: theme.textTheme.titleMedium),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                    FilledButton.tonal(onPressed: _startPlayback, child: const Text('重试')),
                  ],
                ],
              ),
            ),
    );
  }
}

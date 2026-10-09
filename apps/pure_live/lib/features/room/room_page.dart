// Module: lib/features/room/room_page.dart
// Purpose: The live room surface: resolves the entry's ContentRef into a ticket and plays it.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page names no source: it asks the capability registry for the registration the ref's sourceId points
// at and requires a ResolveCapability. A deep link without an extra, or a source that cannot resolve, gets
// an honest surface instead of a spinner or a guessed player.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../../app/di.dart';

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
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    final contentRef = widget.contentRef;
    if (contentRef == null) {
      return;
    }
    final runtime = ref.read(runtimeProvider);
    setState(() {
      _loading = true;
      _error = null;
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
      setState(() => _handle = handle);
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

  @override
  void dispose() {
    // Leaving the room ends the session the page owns: the handle is this page's, opened for it and closed
    // with it. No background playback exists yet, so there is no handover to negotiate.
    _handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handle = _handle;
    return Scaffold(
      appBar: AppBar(title: Text('直播间 ${widget.roomId}')),
      body: handle != null
          ? MediaSurface(handle: handle)
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
                      '从首页卡片进入会带上内容引用并直接出票;直接输入链接暂不解析',
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

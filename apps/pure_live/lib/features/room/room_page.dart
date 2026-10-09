// Module: lib/features/room/room_page.dart
// Purpose: The live room surface. Playback wiring lands with the media wave;
// this page establishes the route and its parameters so source selection can
// navigate here before an engine exists.
// Author: liuchuancong
// Created: 2026-10-09

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final class RoomPage extends StatelessWidget {
  const RoomPage({required this.roomId, super.key});

  /// The room identifier exactly as it appeared in the route. Site-specific
  /// formats are a provider concern; the route keeps the raw string.
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('直播间 $roomId'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: <Widget>[
            Icon(Icons.play_disabled, size: 64, color: theme.colorScheme.outline),
            Text('播放内核未接入', style: theme.textTheme.titleMedium),
            Text(
              '媒体链路(取流 → 内核 → 渲染)在媒体波落地',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// Module: lib/src/episode_panel.dart
// Purpose: The generic episode panel: a scrollable, selectable episode list
// for the player surface, position-marked.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:flutter/material.dart';

/// One episode row in the panel.
final class PlayerEpisode {
  const PlayerEpisode({required this.id, required this.label, this.current = false});

  final String id;
  final String label;
  final bool current;
}

/// The episode list panel; returns the chosen episode's id, or null when
/// dismissed.
Future<String?> showPlayerEpisodePanel(
  BuildContext context, {
  required String title,
  required List<PlayerEpisode> episodes,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (sheetContext, scrollController) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                return ListTile(
                  dense: true,
                  selected: episode.current,
                  leading: episode.current ? const Icon(Icons.play_circle_outline) : Text('${index + 1}'),
                  title: Text(episode.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(sheetContext, episode.id),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:live_uikit/live_uikit.dart';

/// An area tile (3.x `AreaCard`): the square picture and the name.
final class AreaCard extends StatelessWidget {
  /// Shows [area]; [onOpen] opens the area's room list.
  const new({required this.area, required this.onOpen, super.key});

  /// The area this tile shows.
  final LiveArea area;

  /// Called when the tile is tapped.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LiveCard(
            padding: EdgeInsets.zero,
            child: switch (area.iconUrl) {
              final url? when url.isNotEmpty => CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
              _ => const ColoredBox(color: Color(0x22888888), child: Icon(Icons.category_outlined)),
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(area.areaName, maxLines: 1, overflow: TextOverflow.ellipsis, style: LiveTheme.of(context).text.caption),
      ],
    ),
  );
}

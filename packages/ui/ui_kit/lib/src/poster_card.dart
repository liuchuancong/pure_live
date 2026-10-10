// Module: lib/src/poster_card.dart
// Purpose: The poster card used by every content grid: cover, one-line title,
// optional subtitle, tap target.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

/// A poster card. [onTap] is caller-owned navigation; the card renders cover,
/// title and subtitle and nothing else.
final class PosterCard extends StatelessWidget {
  const PosterCard({required this.title, this.subtitle, this.cover, this.onTap, this.width, super.key});

  final String title;
  final String? subtitle;
  final String? cover;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: CoverImage(cover: cover)),
            Padding(
              padding: const EdgeInsets.all(PureLiveSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cover image with an icon placeholder on missing or failed loads.
final class CoverImage extends StatelessWidget {
  const CoverImage({required this.cover, this.icon = Icons.movie_outlined, super.key});

  final String? cover;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Icon(icon, size: 32, color: theme.colorScheme.outline),
    );
    if (cover == null || cover!.isEmpty) {
      return placeholder;
    }
    return Image.network(cover!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, _, _) => placeholder);
  }
}
